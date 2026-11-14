//
//  SettingsGridSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsGridSection: View {
    @Bindable var settings: ConsumptionSettings

    @State private var availableDSOs: [DSOOption] = []
    @State private var isLoadingDSOs = false
    @State private var dsoLoadError: String?

    private let gridTariffService = GridTariffService()

    var body: some View {
        Group {
            if isLoadingDSOs {
                Section {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Laddar elnätsbolag...")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let error = dsoLoadError {
                Section {
                    Text(error)
                        .foregroundStyle(DS.Color.dangerText)
                }
            } else {
                Section {
                    Picker("Elnätsbolag", selection: $settings.selectedDSOOrgNo) {
                        Text("Ingen vald").tag("")
                        ForEach(availableDSOs) { dso in
                            Text(dso.name).tag(dso.id)
                        }
                    }
                    .onChange(of: settings.selectedDSOOrgNo) { _, newValue in
                        Task {
                            await updateGridCompany(newValue)
                        }
                    }

                    Picker("Säkringsstorlek", selection: $settings.fuseSize) {
                        Text("16A").tag(16)
                        Text("20A").tag(20)
                        Text("25A").tag(25)
                        Text("35A").tag(35)
                        Text("50A").tag(50)
                        Text("63A").tag(63)
                    }
                    .onChange(of: settings.fuseSize) { _, newValue in
                        Task {
                            await updateFuseSize(newValue)
                        }
                    }

                    Toggle(EffectTariffCopy.toggleTitle, isOn: $settings.includeHypotheticalEffectTariff)
                } footer: {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        if settings.selectedDSOOrgNo.isEmpty {
                            Text("Elnätskostnad ingår först när du väljer elnätsbolag eller fyller i avgifterna själv.")
                        }
                        Text(EffectTariffCopy.explanation)
                    }
                }

                Section {
                    Picker("Temperaturort", selection: $settings.temperaturePlaceId) {
                        ForEach(TemperaturePlace.presets) { place in
                            Text(place.name).tag(place.id)
                        }
                    }
                } footer: {
                    Text("Används för att jämföra förbrukningen när det varit varmare eller kallare. Standard är Vaggeryd, nära Vaggeryds elnät. Du väljer ort själv, appen använder inte din position. Dygnstemperatur från Open-Meteo.")
                }

                Section {
                    Toggle(ElectricCarCopy.toggleTitle, isOn: $settings.hasElectricCar)
                } footer: {
                    Text(ElectricCarCopy.toggleExplanation)
                }

                Section {
                    LabeledContent("Fast avgift") {
                        HStack(spacing: DS.Spacing.xs) {
                            TextField("0", value: $settings[gridMonthlyFee: SettingsBind.gridMonthlyFee], format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: DS.Size.settingsFieldWidth)
                            Text("kr/mån")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Överföring") {
                        HStack(spacing: DS.Spacing.xs) {
                            TextField("0", value: $settings[gridTransferOre: SettingsBind.gridTransferOre], format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: DS.Size.settingsFieldWidth)
                            Text("öre/kWh")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Egna elnätsavgifter")
                } footer: {
                    Text("Fyll i själv om uppgifterna saknas eller inte stämmer med fakturan. Beloppen som på fakturan, inklusive moms.")
                }

                if !settings.selectedDSOOrgNo.isEmpty,
                   let selectedDSO = availableDSOs.first(where: { $0.id == settings.selectedDSOOrgNo }) {
                    Section {
                        if settings.costProfile.hasUserEnteredGridCosts {
                            Button("Använd elnätsbolagets priser") {
                                Task {
                                    await updateGridCompany(settings.selectedDSOOrgNo, preferImportedValues: true)
                                }
                            }
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(gridCostSourceText(for: selectedDSO.name))

                            if let tariffFreshnessText {
                                Text(tariffFreshnessText)
                                    .foregroundStyle(settings.costProfile.isTariffExpired ? DS.Color.warningText : .secondary)
                            }
                        }
                    }
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
            return "Dina egna elnätsavgifter används för \(dsoName)."
        }
        return "Uppskattade elnätsavgifter för \(dsoName) används när uppgifterna finns."
    }

    private var tariffFreshnessText: String? {
        let profile = settings.costProfile
        guard profile.source == .localPreset || profile.source == .remoteTariff else {
            return nil
        }

        if profile.isTariffExpired {
            return "Elnätspriserna kan vara inaktuella."
        }

        if let validUntil = profile.tariffValidUntil {
            return "Gäller till \(validUntil.formatted(date: .numeric, time: .omitted))."
        }

        if let lastUpdated = profile.tariffLastUpdated {
            return "Hämtad \(lastUpdated.formatted(date: .numeric, time: .shortened))."
        }

        return "Inbyggda elnätspriser används."
    }

    private func loadDSOs() async {
        isLoadingDSOs = true
        dsoLoadError = nil

        do {
            availableDSOs = try await gridTariffService.fetchAvailableDSOs()
        } catch {
            dsoLoadError = "Kunde inte ladda elnätsbolag: \(error.userFacingMessage)"
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
            return
        }

        let tariff = try? await gridTariffService.fetchTariff(forDSO: dsoId, fuseSize: settings.fuseSize)
        settings.cachedTariff = tariff

        if let tariff {
            let shouldPreserveManualGridCosts = settings.costProfile.hasUserEnteredGridCosts && !preferImportedValues
            var next = settings.costProfile.updating(
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
            if let powerTariffPerKW = tariff.powerTariffPerKW {
                next = next.settingEffectTariff(
                    EffectTariff(
                        monthlyPricePerKW: powerTariffPerKW,
                        model: .manual,
                        activeHours: .custom
                    ),
                    confidence: .userConfigured,
                    source: shouldPreserveManualGridCosts ? settings.costProfile.source : .localPreset
                )
            } else {
                next = next.settingEffectTariff(nil)
            }
            settings.costProfile = next
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
    }

    private func updateFuseSize(_ fuseSize: Int) async {
        guard !settings.selectedDSOOrgNo.isEmpty else {
            settings.costProfile = settings.costProfile.updating(
                fuseSize: fuseSize,
                confidence: settings.costProfile.confidence
            )
            return
        }

        await updateGridCompany(settings.selectedDSOOrgNo)
    }
}