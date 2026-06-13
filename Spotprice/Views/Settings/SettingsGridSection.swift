//
//  SettingsGridSection.swift
//  Spotprice
//

import SwiftUI
import WidgetKit

struct SettingsGridSection: View {
    @Bindable var settings: ConsumptionSettings

    @State private var availableDSOs: [DSOOption] = []
    @State private var isLoadingDSOs = false
    @State private var dsoLoadError: String?

    private let gridTariffService = GridTariffService()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Elnät")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            if isLoadingDSOs {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Laddar nätägare...")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)
                }
            } else if let error = dsoLoadError {
                Text(error)
                    .foregroundStyle(DS.Color.danger)
                    .font(DS.Font.regular(11))
            } else {
                Picker("Välj nätägare", selection: $settings.selectedDSOOrgNo) {
                    Text("Ingen vald").tag("")
                    ForEach(availableDSOs) { dso in
                        Text(dso.name).tag(dso.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.selectedDSOOrgNo) { _, newValue in
                    Task {
                        await updateGridCompany(newValue)
                    }
                }

                Picker("Välj säkringsstorlek", selection: $settings.fuseSize) {
                    Text("16A").tag(16)
                    Text("20A").tag(20)
                    Text("25A").tag(25)
                    Text("35A").tag(35)
                    Text("50A").tag(50)
                    Text("63A").tag(63)
                }
                .pickerStyle(.menu)
                .onChange(of: settings.fuseSize) { _, newValue in
                    Task {
                        await updateFuseSize(newValue)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Fast elnätsavgift (kr/mån)")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)

                    TextField("0", value: $settings[gridMonthlyFee: SettingsBind.gridMonthlyFee], format: .number)
                        .textFieldStyle(.roundedBorder)
                        .help("Ange din fasta elnätsavgift per månad om tariffdata saknas eller avviker.")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Överföringsavgift (öre/kWh)")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)

                    TextField("0", value: $settings[gridTransferOre: SettingsBind.gridTransferOre], format: .number)
                        .textFieldStyle(.roundedBorder)
                        .help("Ange rörlig nätavgift i öre/kWh om tariffdata saknas eller avviker.")
                }

                if !settings.selectedDSOOrgNo.isEmpty,
                   let selectedDSO = availableDSOs.first(where: { $0.id == settings.selectedDSOOrgNo }) {
                    Text(gridCostSourceText(for: selectedDSO.name))
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)

                    if let tariffFreshnessText {
                        Text(tariffFreshnessText)
                            .font(DS.Font.micro)
                            .foregroundStyle(settings.costProfile.isTariffExpired ? DS.Color.warning : DS.Color.secondary)
                    }

                    if settings.costProfile.hasUserEnteredGridCosts {
                        Button("Använd tariffvärden") {
                            Task {
                                await updateGridCompany(settings.selectedDSOOrgNo, preferImportedValues: true)
                            }
                        }
                        .font(DS.Font.medium(11))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                } else {
                    Text("Elnätskostnad ingår först när du väljer nätägare eller anger nätavgifter.")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)
                }
            }
        }
        .task {
            await loadDSOs()
        }
    }

    private var selectedDSOName: String? {
        availableDSOs.first(where: { $0.id == settings.selectedDSOOrgNo })?.name
    }

    private func gridCostSourceText(for dsoName: String) -> String {
        if settings.costProfile.hasUserEnteredGridCosts {
            return "Dina egna nätavgifter används för \(dsoName)."
        }
        return "Uppskattade nätavgifter för \(dsoName) används när tariffdata finns."
    }

    private var tariffFreshnessText: String? {
        let profile = settings.costProfile
        guard profile.source == .localPreset || profile.source == .remoteTariff else {
            return nil
        }

        if profile.isTariffExpired {
            return "Tariffdata kan vara inaktuell."
        }

        if let validUntil = profile.tariffValidUntil {
            return "Tariff giltig till \(validUntil.formatted(date: .numeric, time: .omitted))."
        }

        if let lastUpdated = profile.tariffLastUpdated {
            return "Tariff hämtad \(lastUpdated.formatted(date: .numeric, time: .shortened))."
        }

        return "Lokal tariffpresets används."
    }

    private func loadDSOs() async {
        isLoadingDSOs = true
        dsoLoadError = nil

        do {
            availableDSOs = try await gridTariffService.fetchAvailableDSOs()
        } catch {
            dsoLoadError = "Kunde inte ladda nätägare: \(error.userFacingMessage)"
        }

        isLoadingDSOs = false
    }

    private func updateGridCompany(_ dsoId: String, preferImportedValues: Bool = false) async {
        guard !dsoId.isEmpty else {
            settings.costProfile = settings.costProfile
                .removingGridCosts(
                    gridCompanyId: nil,
                    gridCompanyName: nil,
                    fuseSize: settings.fuseSize
                )
                .applyingInferredConfidence(configuredSource: .userEntered)
            settings.cachedTariff = nil
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let tariff = try? await gridTariffService.fetchTariff(forDSO: dsoId, fuseSize: settings.fuseSize)
        settings.cachedTariff = tariff

        if let tariff {
            let shouldPreserveManualGridCosts = settings.costProfile.hasUserEnteredGridCosts && !preferImportedValues
            settings.costProfile = settings.costProfile.updating(
                gridCompanyId: dsoId,
                gridCompanyName: tariff.dsoName,
                fuseSize: settings.fuseSize,
                gridMonthlyFee: shouldPreserveManualGridCosts ? settings.costProfile.gridMonthlyFee : tariff.monthlyFixedFee,
                gridTransferOrePerKWh: shouldPreserveManualGridCosts ? settings.costProfile.gridTransferOrePerKWh : tariff.energyTariffPerKWh * 100.0,
                gridCostSource: shouldPreserveManualGridCosts ? .userEntered : .localPreset,
                energyTaxOrePerKWh: tariff.energyTaxPerKWh,
                certificateFeeOrePerKWh: tariff.certificateFeePerKWh,
                confidence: .userConfigured,
                source: shouldPreserveManualGridCosts ? settings.costProfile.source : .localPreset,
                tariffLastUpdated: Date(),
                tariffValidUntil: tariff.validTo
            )
        } else {
            if settings.costProfile.hasUserEnteredGridCosts {
                settings.costProfile = settings.costProfile.updating(
                    gridCompanyId: dsoId,
                    gridCompanyName: selectedDSOName,
                    fuseSize: settings.fuseSize,
                    gridCostSource: .userEntered,
                    confidence: .userConfigured,
                    source: .userEntered
                )
            } else {
                settings.costProfile = settings.costProfile.removingGridCosts(
                    gridCompanyId: dsoId,
                    gridCompanyName: selectedDSOName,
                    fuseSize: settings.fuseSize,
                    confidence: .userConfigured,
                    source: .userEntered
                )
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func updateFuseSize(_ fuseSize: Int) async {
        guard !settings.selectedDSOOrgNo.isEmpty else {
            settings.costProfile = settings.costProfile.updating(
                fuseSize: fuseSize,
                confidence: settings.costProfile.confidence
            )
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        await updateGridCompany(settings.selectedDSOOrgNo)
    }
}