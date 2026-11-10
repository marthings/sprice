import SwiftUI

struct AppSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focusedField: Field?

    @State private var priceArea = "SE3"
    @State private var contractType: RetailContractType = .spotPriceMarkup
    @State private var retailerMarkupOrePerKWh = 0.0
    @State private var contractPriceOrePerKWh = 0.0
    @State private var retailerMonthlyFee = 0.0
    @State private var compareFixedPriceOrePerKWh = CostUsageInsights.defaultFixedPriceOrePerKWh
    @State private var temperaturePlaceId = TemperaturePlace.defaultID(forDSO: "")
    @State private var selectedDSOOrgNo = ""
    @State private var fuseSize = 20
    @State private var includeHypotheticalEffectTariff = false
    @State private var hasElectricCar = false
    @State private var dsoOptions: [DSOOption] = []
    @State private var gridTariffError: String?
    @State private var fieldError: String?
    @State private var showSaved = false
    @State private var isReady = false
    @State private var isCommitting = false
    @State private var pendingSave: Task<Void, Never>?
    @State private var hideSavedTask: Task<Void, Never>?

    private let settings = ConsumptionSettings.shared
    private let gridTariffService = GridTariffService()
    private let fuseSizes = [16, 20, 25, 35, 50, 63]

    private enum Field: Hashable {
        case markup
        case contractPrice
        case monthlyFee
        case compareFixedPrice
    }

    var body: some View {
        Form {
            overviewSection
            consumptionSection
            priceAreaSection
            retailContractSection
            gridTariffSection
            temperaturePlaceSection
            electricCarSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.top, DS.Spacing.titleToContent, for: .scrollContent)
        .listSectionSpacing(DS.Spacing.md)
        .environment(\.defaultMinListHeaderHeight, 0)
        .font(DS.Font.body)
        .textFieldStyle(.plain)
        .onAppear {
            guard !isReady else { return }
            loadSettings()
        }
        .task {
            await loadDSOOptions()
        }
        .onDisappear {
            flushPendingSave()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                flushPendingSave()
            }
        }
        .onChange(of: priceArea) { _, _ in commitImmediately() }
        .onChange(of: contractType) { _, _ in commitImmediately() }
        .onChange(of: selectedDSOOrgNo) { _, _ in commitImmediately() }
        .onChange(of: fuseSize) { _, _ in commitImmediately() }
        .onChange(of: includeHypotheticalEffectTariff) { _, _ in commitEffectTariffToggle() }
        .onChange(of: hasElectricCar) { _, _ in commitElectricCarToggle() }
        .onChange(of: retailerMarkupOrePerKWh) { _, _ in scheduleCommit() }
        .onChange(of: contractPriceOrePerKWh) { _, _ in scheduleCommit() }
        .onChange(of: retailerMonthlyFee) { _, _ in scheduleCommit() }
        .onChange(of: compareFixedPriceOrePerKWh) { _, _ in scheduleCommit() }
        .onChange(of: temperaturePlaceId) { _, _ in scheduleCommit() }
        .onChange(of: focusedField) { _, newValue in
            if newValue == nil {
                flushPendingSave()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if showSaved {
                    SettingsSavedLabel()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Klar") {
                    focusedField = nil
                }
            }
        }
    }

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(overviewLine)
                    .font(DS.Font.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let overviewStatus {
                    Text(overviewStatus)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .spriceListRowBackground()
        }
    }

    private var consumptionSection: some View {
        Section {
            NavigationLink {
                ProviderSettingsView()
            } label: {
                LabeledContent("Datakälla") {
                    Text(providerStatusText)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .accessibilityHint("Öppnar inställningar för förbrukningsdata")
            .spriceListRowBackground()
        } header: {
            Text("Förbrukning")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text("Används för månadsförbrukning, effekttoppar och mer träffsäkra kostnader.")
                .spriceSettingsFooterStyle()
        }
    }

    private var priceAreaSection: some View {
        Section {
            SpriceSettingsMenuPicker(title: "Elområde", selection: $priceArea, valueText: priceArea) {
                ForEach(["SE1", "SE2", "SE3", "SE4"], id: \.self) { area in
                    Text(area).tag(area)
                }
            }
        } header: {
            Text("Elområde")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text("Spotpriser hämtas för valt elområde.")
                .spriceSettingsFooterStyle()
        }
    }

    private var retailContractSection: some View {
        Section {
            SpriceSettingsMenuPicker(title: "Avtal", selection: $contractType, valueText: contractOverviewName) {
                Text("Kvartspris").tag(RetailContractType.spotPriceMarkup)
                Text("Rörligt månadspris").tag(RetailContractType.variableMonthlyPrice)
                Text("Fast pris").tag(RetailContractType.fixedPrice)
            }

            currencyField(
                title: "Påslag",
                value: $retailerMarkupOrePerKWh,
                unit: "öre/kWh",
                field: .markup
            )

            if contractType != .spotPriceMarkup {
                currencyField(
                    title: contractType == .fixedPrice ? "Fast pris" : "Månadspris",
                    value: $contractPriceOrePerKWh,
                    unit: "öre/kWh",
                    field: .contractPrice
                )
            }

            currencyField(
                title: "Månadsavgift",
                value: $retailerMonthlyFee,
                unit: "kr/mån",
                field: .monthlyFee
            )

            currencyField(
                title: "Jämför med fast pris",
                value: $compareFixedPriceOrePerKWh,
                unit: "öre/kWh",
                field: .compareFixedPrice
            )

            if let fieldError {
                Label(fieldError, systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.warning)
                    .spriceListRowBackground()
            }
        } header: {
            Text("Elhandel")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text(contractFooterText)
                .spriceSettingsFooterStyle()
        }
    }

    private var gridTariffSection: some View {
        Section {
            SpriceSettingsMenuPicker(title: "Elnät", selection: $selectedDSOOrgNo, valueText: selectedDSOName) {
                Text("Inget valt").tag("")
                ForEach(dsoOptions) { option in
                    Text(option.name).tag(option.id)
                }
            }

            SpriceSettingsMenuPicker(
                title: "Säkring",
                selection: $fuseSize,
                valueText: "\(fuseSize) A",
                monospacedValue: true
            ) {
                ForEach(fuseSizes, id: \.self) { size in
                    Text("\(size) A").tag(size)
                }
            }

            Toggle(isOn: $includeHypotheticalEffectTariff) {
                Text(EffectTariffCopy.toggleTitle)
                    .font(DS.Font.body)
            }
            .accessibilityHint(EffectTariffCopy.explanation)
            .spriceListRowBackground()

            if let gridTariffError {
                Label(gridTariffError, systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.warning)
                    .spriceListRowBackground()
            } else if let gridTariffSummary {
                Label(gridTariffSummary, systemImage: "checkmark.circle.fill")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.secondary)
                    .spriceListRowBackground()
            }
        } header: {
            Text("Elnät")
                .spriceSettingsHeaderStyle()
        } footer: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Elnätskostnader används i totalpriset tillsammans med spotpris, elhandel och moms. Beloppen anges som på fakturan, inklusive moms.")
                Text(EffectTariffCopy.explanation)
            }
            .spriceSettingsFooterStyle()
        }
    }


    private var temperaturePlaceSection: some View {
        Section {
            SpriceSettingsMenuPicker(
                title: "Temperaturort",
                selection: $temperaturePlaceId,
                valueText: TemperaturePlace.place(id: temperaturePlaceId).name
            ) {
                ForEach(TemperaturePlace.presets) { place in
                    Text(place.name).tag(place.id)
                }
            }
        } header: {
            Text("Temperatur")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text("Används för att jämföra förbrukningen när det varit varmare eller kallare. Standard är Vaggeryd, nära Vaggeryds elnät. Du väljer ort själv, appen använder inte din position. Dygnstemperatur från Open-Meteo.")
                .spriceSettingsFooterStyle()
        }
    }

    private var electricCarSection: some View {
        Section {
            Toggle(isOn: $hasElectricCar) {
                Text(ElectricCarCopy.toggleTitle)
                    .font(DS.Font.body)
            }
            .accessibilityHint(ElectricCarCopy.toggleExplanation)
            .spriceListRowBackground()
        } header: {
            Text("Elbil")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text(ElectricCarCopy.toggleExplanation)
                .spriceSettingsFooterStyle()
        }
    }

    private func currencyField(
        title: String,
        value: Binding<Double>,
        unit: String,
        field: Field
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: DS.Spacing.xs) {
                TextField(title, value: value, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(DS.Font.body.monospacedDigit())
                    .focused($focusedField, equals: field)
                    .submitLabel(.done)
                    .onSubmit {
                        flushPendingSave()
                    }
                    .accessibilityLabel(title)
                Text(unit)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondary)
                    .accessibilityHidden(true)
            }
        }
        .spriceListRowBackground()
    }

    private var contractFooterText: String {
        let compare = "Jämför med fast pris används bara för att visa skillnaden mot spot. Standard är 120 öre/kWh inklusive moms."
        switch contractType {
        case .spotPriceMarkup:
            return "Totalpriset följer spotpriset plus påslag, skatter, elnät och moms. Påslag, skatt och elnät anges som på fakturan, inklusive moms. Spotpriset hämtas utan moms. " + compare
        case .variableMonthlyPrice:
            return "Totalpriset använder ditt rörliga månadspris för elhandeln, inklusive moms. " + compare
        case .fixedPrice:
            return "Totalpriset använder ditt fasta avtalade pris för elhandeln, inklusive moms. " + compare
        }
    }

    private var overviewLine: String {
        "\(priceArea), \(contractOverviewName), \(providerOverviewName)"
    }

    private var contractOverviewName: String {
        switch contractType {
        case .spotPriceMarkup:
            return "Kvartspris"
        case .variableMonthlyPrice:
            return "Rörligt månadspris"
        case .fixedPrice:
            return "Fast pris"
        }
    }

    private var selectedDSOName: String {
        if selectedDSOOrgNo.isEmpty {
            return "Inget valt"
        }
        return dsoOptions.first(where: { $0.id == selectedDSOOrgNo })?.name ?? "Inget valt"
    }

    private var providerOverviewName: String {
        providerMetadata?.displayName ?? "Ingen leverantör"
    }

    private var overviewStatus: String? {
        guard let metadata = providerMetadata else { return nil }
        let credentials = settings.getCredentials(for: metadata.identifier)
        return credentials.isComplete(for: metadata.credentialFields)
            ? "Konfigurerad"
            : "Saknar uppgifter"
    }

    private var providerMetadata: ProviderMetadata? {
        guard !settings.selectedProviderId.isEmpty else { return nil }
        return ProviderRegistry.shared.metadata(for: settings.selectedProviderId)
    }

    private var providerStatusText: String {
        guard let metadata = providerMetadata else {
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
        includeHypotheticalEffectTariff = settings.includeHypotheticalEffectTariff
        hasElectricCar = settings.hasElectricCar
        compareFixedPriceOrePerKWh = settings.compareFixedPriceOrePerKWh
        temperaturePlaceId = settings.temperaturePlaceId
        isReady = true
    }

    private func loadDSOOptions() async {
        do {
            dsoOptions = try await gridTariffService.fetchAvailableDSOs()
            gridTariffError = nil
        } catch {
            gridTariffError = "Kunde inte hämta elnätsbolag."
        }
    }

    private func scheduleCommit() {
        guard isReady else { return }
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await commitSettings()
        }
    }

    private func commitImmediately() {
        guard isReady else { return }
        pendingSave?.cancel()
        Task { await commitSettings() }
    }

    private func commitEffectTariffToggle() {
        guard isReady else { return }
        let previous = settings.includeHypotheticalEffectTariff
        settings.includeHypotheticalEffectTariff = includeHypotheticalEffectTariff
        if previous != includeHypotheticalEffectTariff {
            showSaved = true
            hideSavedTask?.cancel()
            hideSavedTask = Task {
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                showSaved = false
            }
        }
    }

    private func commitElectricCarToggle() {
        guard isReady else { return }
        let previous = settings.hasElectricCar
        settings.hasElectricCar = hasElectricCar
        if previous != hasElectricCar {
            showSaved = true
            hideSavedTask?.cancel()
            hideSavedTask = Task {
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                showSaved = false
            }
        }
    }

    private func flushPendingSave() {
        pendingSave?.cancel()
        Task { await commitSettings() }
    }

    @MainActor
    private func commitSettings() async {
        guard isReady, !isCommitting else { return }
        isCommitting = true
        defer { isCommitting = false }

        if let message = validationMessage {
            fieldError = message
            return
        }
        fieldError = nil
        settings.compareFixedPriceOrePerKWh = compareFixedPriceOrePerKWh
        settings.temperaturePlaceId = temperaturePlaceId

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

        let gridSelectionChanged =
            selectedDSOOrgNo != (settings.costProfile.gridCompanyId ?? settings.selectedDSOOrgNo) ||
            fuseSize != (settings.costProfile.fuseSize ?? settings.fuseSize)

        if selectedDSOOrgNo.isEmpty {
            settings.selectedDSOOrgNo = ""
            settings.fuseSize = fuseSize
            settings.cachedTariff = nil
            next = next.removingGridCosts(
                fuseSize: fuseSize,
                confidence: next.inferredConfidence(),
                source: .userEntered
            )
        } else if gridSelectionChanged {
            do {
                guard let tariff = try await gridTariffService.fetchTariff(forDSO: selectedDSOOrgNo, fuseSize: fuseSize) else {
                    gridTariffError = "Hittade inga elnätspriser för valt elnät."
                    let previous = settings.costProfile
                    settings.costProfile = next.applyingInferredConfidence(configuredSource: .userEntered)
                    flashSavedIfNeeded(previous: previous)
                    return
                }

                settings.selectedDSOOrgNo = selectedDSOOrgNo
                settings.fuseSize = tariff.fuseSize ?? fuseSize
                settings.cachedTariff = tariff
                next = applyGridTariff(tariff, to: next)
                gridTariffError = nil
            } catch {
                gridTariffError = "Kunde inte spara elnätskostnader."
                let previous = settings.costProfile
                settings.costProfile = next.applyingInferredConfidence(configuredSource: .userEntered)
                flashSavedIfNeeded(previous: previous)
                return
            }
        }

        let previous = settings.costProfile
        settings.costProfile = next.applyingInferredConfidence(configuredSource: .userEntered)
        flashSavedIfNeeded(previous: previous)
    }

    private var validationMessage: String? {
        if retailerMarkupOrePerKWh < 0 || retailerMonthlyFee < 0 || contractPriceOrePerKWh < 0 || compareFixedPriceOrePerKWh < 0 {
            return "Ange 0 eller mer."
        }
        return nil
    }

    private func flashSavedIfNeeded(previous: CostProfile) {
        guard settings.costProfile != previous else { return }
        showSaved = true
        hideSavedTask?.cancel()
        hideSavedTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            showSaved = false
        }
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
        } else {
            next = next.settingEffectTariff(nil)
        }

        return next
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
            .background { AppCanvasBackground() }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.large)
    }
}
