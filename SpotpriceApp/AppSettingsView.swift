import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var priceArea = "SE3"
    @State private var contractType: RetailContractType = .spotPriceMarkup
    @State private var retailerMarkupOrePerKWh = 0.0
    @State private var contractPriceOrePerKWh = 0.0
    @State private var retailerMonthlyFee = 0.0
    @State private var selectedDSOOrgNo = ""
    @State private var fuseSize = 20
    @State private var dsoOptions: [DSOOption] = []
    @State private var gridTariffError: String?
    @State private var isSaving = false

    private let settings = ConsumptionSettings.shared
    private let gridTariffService = GridTariffService()
    private let fuseSizes = [16, 20, 25, 35, 50, 63]

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                priceAreaSection
                retailContractSection
                gridTariffSection
                saveSection
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: loadSettings)
            .task {
                await loadDSOOptions()
            }
        }
    }

    private var providerSection: some View {
        Section {
            NavigationLink {
                ProviderSettingsView()
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bolt.badge.meter")
                        .foregroundStyle(DS.Color.info)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Förbrukning")
                            .font(DS.Font.callout)
                        Text(providerStatusText)
                            .font(DS.Font.micro)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var priceAreaSection: some View {
        Section {
            Picker("Elområde", selection: $priceArea) {
                ForEach(["SE1", "SE2", "SE3", "SE4"], id: \.self) { area in
                    Text(area).tag(area)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Elområde")
                .font(DS.Font.caption)
        } footer: {
            Text("Spotpriser hämtas för valt elområde.")
                .font(DS.Font.micro)
        }
    }

    private var retailContractSection: some View {
        Section {
            Picker("Avtal", selection: $contractType) {
                Text("Kvartspris").tag(RetailContractType.spotPriceMarkup)
                Text("Rörligt").tag(RetailContractType.variableMonthlyPrice)
                Text("Fast").tag(RetailContractType.fixedPrice)
            }
            .pickerStyle(.segmented)

            currencyField(
                title: "Påslag",
                value: $retailerMarkupOrePerKWh,
                unit: "öre/kWh"
            )

            if contractType != .spotPriceMarkup {
                currencyField(
                    title: contractType == .fixedPrice ? "Fast pris" : "Månadspris",
                    value: $contractPriceOrePerKWh,
                    unit: "öre/kWh"
                )
            }

            currencyField(
                title: "Månadsavgift",
                value: $retailerMonthlyFee,
                unit: "kr/mån"
            )
        } header: {
            Text("Elhandel")
                .font(DS.Font.caption)
        } footer: {
            Text(contractFooterText)
                .font(DS.Font.micro)
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                Task {
                    await saveSettings()
                }
            } label: {
                Label(isSaving ? "Sparar" : "Spara", systemImage: "checkmark.circle.fill")
                    .font(DS.Font.callout)
                    .frame(maxWidth: .infinity)
            }
            .disabled(isSaving)
        }
    }

    private var gridTariffSection: some View {
        Section {
            Picker("Elnät", selection: $selectedDSOOrgNo) {
                Text("Inget valt").tag("")
                ForEach(dsoOptions) { option in
                    Text(option.name).tag(option.id)
                }
            }

            Picker("Säkring", selection: $fuseSize) {
                ForEach(fuseSizes, id: \.self) { size in
                    Text("\(size) A").tag(size)
                }
            }

            if let gridTariffError {
                Label(gridTariffError, systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.warning)
            } else if let gridTariffSummary {
                Label(gridTariffSummary, systemImage: "checkmark.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Elnät")
                .font(DS.Font.caption)
        } footer: {
            Text("Elnätskostnader används i totalpriset tillsammans med spotpris och elhandel.")
                .font(DS.Font.micro)
        }
    }

    private func currencyField(title: String, value: Binding<Double>, unit: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Font.callout)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(DS.Font.callout.monospacedDigit())
                .frame(maxWidth: 110)
            Text(unit)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
        }
    }

    private var contractFooterText: String {
        switch contractType {
        case .spotPriceMarkup:
            return "Totalpriset följer spotpriset plus påslag, skatter och elnätskostnader."
        case .variableMonthlyPrice:
            return "Totalpriset använder ditt rörliga månadspris för elhandeln."
        case .fixedPrice:
            return "Totalpriset använder ditt fasta avtalade pris för elhandeln."
        }
    }

    private var providerStatusText: String {
        guard !settings.selectedProviderId.isEmpty,
              let metadata = ProviderRegistry.shared.metadata(for: settings.selectedProviderId) else {
            return "Ingen leverantör vald"
        }

        let credentials = settings.getCredentials(for: metadata.identifier)
        return credentials.isComplete(for: metadata.credentialFields)
            ? "\(metadata.displayName) är konfigurerad"
            : "\(metadata.displayName) saknar uppgifter"
    }

    private var gridTariffSummary: String? {
        let profile = settings.costProfile
        guard let name = profile.gridCompanyName,
              let monthlyFee = profile.gridMonthlyFee,
              let transfer = profile.gridTransferOrePerKWh else {
            return nil
        }

        return "\(name): \(monthlyFee.formatted(.number.precision(.fractionLength(0)))) kr/mån, \(transfer.formatted(.number.precision(.fractionLength(1)))) öre/kWh"
    }

    private func loadSettings() {
        let profile = settings.costProfile
        priceArea = profile.priceArea
        contractType = profile.retailContractType
        retailerMarkupOrePerKWh = profile.retailerMarkupOrePerKWh
        contractPriceOrePerKWh = profile.contractPriceOrePerKWh ?? 0
        retailerMonthlyFee = profile.retailerMonthlyFee
        selectedDSOOrgNo = profile.gridCompanyId ?? settings.selectedDSOOrgNo
        fuseSize = profile.fuseSize ?? settings.fuseSize
    }

    private func loadDSOOptions() async {
        do {
            dsoOptions = try await gridTariffService.fetchAvailableDSOs()
            gridTariffError = nil
        } catch {
            gridTariffError = "Kunde inte hämta elnätsbolag."
        }
    }

    private func saveSettings() async {
        isSaving = true
        defer { isSaving = false }

        var next = settings.costProfile.updating(priceArea: priceArea)
        next = next.settingRetailContract(
            type: contractType,
            retailerMarkupOrePerKWh: retailerMarkupOrePerKWh,
            contractPriceOrePerKWh: contractType == .spotPriceMarkup ? nil : contractPriceOrePerKWh,
            retailerMonthlyFee: retailerMonthlyFee,
            retailContractSource: .userEntered,
            confidence: .userConfigured,
            source: .userEntered
        )

        if selectedDSOOrgNo.isEmpty {
            settings.selectedDSOOrgNo = ""
            settings.fuseSize = fuseSize
            settings.cachedTariff = nil
            next = next.removingGridCosts(
                fuseSize: fuseSize,
                confidence: next.inferredConfidence(),
                source: .userEntered
            )
        } else {
            do {
                guard let tariff = try await gridTariffService.fetchTariff(forDSO: selectedDSOOrgNo, fuseSize: fuseSize) else {
                    gridTariffError = "Hittade ingen tariff för valt elnät."
                    return
                }

                settings.selectedDSOOrgNo = selectedDSOOrgNo
                settings.fuseSize = tariff.fuseSize ?? fuseSize
                settings.cachedTariff = tariff
                next = applyGridTariff(tariff, to: next)
                gridTariffError = nil
            } catch {
                gridTariffError = "Kunde inte spara elnätskostnader."
                return
            }
        }

        settings.costProfile = next.applyingInferredConfidence(configuredSource: .userEntered)
        dismiss()
    }

    private func applyGridTariff(_ tariff: SimplifiedTariff, to profile: CostProfile) -> CostProfile {
        var next = profile.updating(
            gridCompanyId: tariff.dsoOrgNo,
            gridCompanyName: tariff.dsoName,
            fuseSize: tariff.fuseSize ?? fuseSize,
            gridMonthlyFee: tariff.monthlyFixedFee,
            gridTransferOrePerKWh: tariff.energyTariffPerKWh * 100,
            gridCostSource: .localPreset,
            energyTaxOrePerKWh: tariff.energyTaxPerKWh,
            certificateFeeOrePerKWh: tariff.certificateFeePerKWh,
            confidence: .userConfigured,
            source: .userEntered,
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
                source: .userEntered
            )
        }

        return next
    }
}

#Preview {
    AppSettingsView()
}
