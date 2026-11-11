import SwiftUI
import UIKit

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
        ScrollViewReader { proxy in
            form
#if DEBUG
                .task {
                    // DEBUG only: `-ScrollTo history` scrolls to a section, for screenshots.
                    let arguments = ProcessInfo.processInfo.arguments
                    guard let index = arguments.firstIndex(of: "-ScrollTo"), arguments.indices.contains(index + 1) else { return }
                    try? await Task.sleep(for: .seconds(2))
                    proxy.scrollTo(arguments[index + 1], anchor: .top)
                }
#endif
        }
    }

    private var form: some View {
        Form {
            overviewSection
            demoSection.id("demo")
            consumptionSection
            priceAreaSection
            retailContractSection
            gridTariffSection
            temperaturePlaceSection
            electricCarSection
            SettingsHistoryDataSection().id("history")
            aboutSection.id("about")
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
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .spriceListRowBackground()
        }
    }

    private var demoSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.isDemoActive },
                set: { settings.setDemoMode($0) }
            )) {
                Text("Visa exempeldata")
                    .font(DS.Font.body)
            }
            .accessibilityHint("Visar påhittad data så att du kan prova appen utan konto")
            .spriceListRowBackground()
        } header: {
            Text("Exempeldata")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text("Visar påhittad data för ett hushåll som inte finns, så att du kan prova appen utan konto. Din riktiga data ändras inte.")
                .spriceSettingsFooterStyle()
        }
    }

    private var consumptionSection: some View {
        Section {
            if settings.isDemoActive {
                LabeledContent("Datakälla") {
                    Text(providerStatusText)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .spriceListRowBackground()
            } else {
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
            }
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
                    .foregroundStyle(DS.Color.warningText)
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
                    .foregroundStyle(DS.Color.warningText)
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

    private var aboutSection: some View {
        Section {
            Link(destination: AppLinks.privacyPolicy) {
                LabeledContent("Integritetspolicy") {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(DS.Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint("Öppnar sidan i webbläsaren")
            .spriceListRowBackground()

            Link(destination: AppLinks.support) {
                LabeledContent("Support") {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(DS.Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint("Öppnar sidan i webbläsaren")
            .spriceListRowBackground()

            Link(destination: AppLinks.priceSource) {
                LabeledContent("Elpriser från Elpriset just nu.se") {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(DS.Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint("Öppnar sidan i webbläsaren")
            .spriceListRowBackground()

            Link(destination: AppLinks.temperatureSource) {
                LabeledContent("Temperatur från Open-Meteo.com") {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(DS.Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint("Öppnar sidan i webbläsaren")
            .spriceListRowBackground()
        } header: {
            Text("Om Sprice")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text("All data stannar på din telefon. Appen har ingen inloggning hos oss, inga annonser och ingen spårning.")
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
        if settings.isDemoActive { return "Exempeldata" }
        return providerMetadata?.displayName ?? "Ingen leverantör"
    }

    private var overviewStatus: String? {
        if settings.isDemoActive { return "Påhittad data, inget är sparat" }
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
        if settings.isDemoActive { return "Exempeldata visas" }
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


// MARK: - Saved history: export and delete

struct SettingsHistoryDataSection: View {
    @State private var status = "Läser sparad historik..."
    @State private var isPreparingExport = false
    @State private var shareItem: HistoryShareItem?
    @State private var isConfirmingDeletion = false

    private let settings = ConsumptionSettings.shared

    var body: some View {
        Section {
            Text(status)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.secondary)
                .spriceListRowBackground()

            Button {
                exportHistory()
            } label: {
                HStack {
                    Label("Exportera historik", systemImage: "square.and.arrow.up")
                        .font(DS.Font.body)
                    Spacer()
                    if isPreparingExport {
                        ProgressView()
                    }
                }
            }
            .disabled(isPreparingExport)
            .accessibilityHint("Öppnar delningsmenyn med historiken som en CSV-fil")
            .spriceListRowBackground()

            Button(role: .destructive) {
                isConfirmingDeletion = true
            } label: {
                Label("Radera historik", systemImage: "trash")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.dangerText)
            }
            .accessibilityHint("Tar bort all sparad historik från telefonen efter en bekräftelse")
            .spriceListRowBackground()
        } header: {
            Text("Sparad historik")
                .spriceSettingsHeaderStyle()
        } footer: {
            Text("Historiken sparas bara på den här telefonen och delas med widgeten. Exporten är en CSV-fil du kan öppna i till exempel Numbers eller Excel.")
                .spriceSettingsFooterStyle()
        }
        .onAppear { loadStatus() }
        .sheet(item: $shareItem) { item in
            HistoryShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Radera historiken?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Radera historik", role: .destructive) {
                deleteHistory()
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Det här tar bort all sparad förbrukning, alla sparade priser och alla uträknade kostnader från den här telefonen, för alla månader. Det går inte att ångra. Dina inställningar och inloggningar finns kvar, och inget raderas hos Tibber, Vaggeryds Energi eller ditt elnätsbolag. Om du är kopplad till en datakälla kan appen hämta ny förbrukning senare.")
        }
    }

    private func loadStatus() {
        do {
            let store = try EnergyHistoryStores.reader()
            let months = try store.fetchMonthlySummaries(priceArea: nil)
            let monthCount = Set(months.map(\.periodKey)).count
            switch monthCount {
            case 0: status = "Ingen sparad historik ännu."
            case 1: status = "1 sparad månad."
            default: status = "\(monthCount) sparade månader."
            }
        } catch {
            status = "Kunde inte läsa historiken: \(error.userFacingMessage)"
        }
    }

    private func exportHistory() {
        isPreparingExport = true
        status = "Förbereder exporten..."
        let priceArea = settings.priceArea
        Task {
            defer { isPreparingExport = false }
            do {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("sprice-history-\(priceArea).csv", isDirectory: false)
                let writer = try EnergyHistoryStores.writer()
                try await writer.exportHistoryCSV(priceArea: priceArea, to: url)
                loadStatus()
                shareItem = HistoryShareItem(url: url)
            } catch {
                status = "Kunde inte exportera historiken: \(error.userFacingMessage)"
            }
        }
    }

    private func deleteHistory() {
        Task {
            do {
                let writer = try EnergyHistoryStores.writer()
                try await writer.deleteAllHistory()
                WidgetHistorySummaryCache.clear()
                WidgetReload.timelines()
                NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                status = "Historiken är raderad."
            } catch {
                status = "Kunde inte radera historiken: \(error.userFacingMessage)"
            }
        }
    }
}

private struct HistoryShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct HistoryShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
