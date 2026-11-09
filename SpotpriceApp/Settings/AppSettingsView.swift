import SwiftUI

struct AppSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focusedField: Field?

    @State private var priceArea = "SE3"
    @State private var contractType: RetailContractType = .spotPriceMarkup
    @State private var retailerMarkupOrePerKWh = 0.0
    @State private var contractPriceOrePerKWh = 0.0
    @State private var retailerMonthlyFee = 0.0
    @State private var selectedDSOOrgNo = ""
    @State private var fuseSize = 20
    @State private var includeHypotheticalEffectTariff = false
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            savedRow

            providerCard
            priceAreaCard
            retailContractCard
            gridTariffCard
        }
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
        .onChange(of: retailerMarkupOrePerKWh) { _, _ in scheduleCommit() }
        .onChange(of: contractPriceOrePerKWh) { _, _ in scheduleCommit() }
        .onChange(of: retailerMonthlyFee) { _, _ in scheduleCommit() }
        .onChange(of: focusedField) { _, newValue in
            if newValue == nil {
                flushPendingSave()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Klar") {
                    focusedField = nil
                }
            }
        }
    }

    private var savedRow: some View {
        HStack {
            Spacer(minLength: 0)
            if showSaved {
                SettingsSavedLabel()
            }
        }
        .frame(minHeight: 16)
        .accessibilityHidden(!showSaved)
    }

    private var providerCard: some View {
        SettingsCard(
            title: "Förbrukning",
            footer: "Används för månadsförbrukning, effekttoppar och mer träffsäkra kostnader."
        ) {
            NavigationLink {
                ProviderSettingsView()
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bolt.badge.meter")
                        .foregroundStyle(DS.Color.info)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Datakälla")
                            .font(DS.Font.callout)
                            .foregroundStyle(.primary)
                        Text(providerStatusText)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }

                    Spacer(minLength: DS.Spacing.sm)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öppnar inställningar för förbrukningsdata")
        }
    }

    private var priceAreaCard: some View {
        SettingsCard(
            title: "Elområde",
            footer: "Spotpriser hämtas för valt elområde."
        ) {
            Picker("Elområde", selection: $priceArea) {
                ForEach(["SE1", "SE2", "SE3", "SE4"], id: \.self) { area in
                    Text(area).tag(area)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Elområde")
        }
    }

    private var retailContractCard: some View {
        SettingsCard(
            title: "Elhandel",
            footer: contractFooterText
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Picker("Avtal", selection: $contractType) {
                    Text("Kvartspris").tag(RetailContractType.spotPriceMarkup)
                    Text("Rörligt").tag(RetailContractType.variableMonthlyPrice)
                    Text("Fast").tag(RetailContractType.fixedPrice)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Avtal")

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

                if let fieldError {
                    Label(fieldError, systemImage: "exclamationmark.triangle.fill")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var gridTariffCard: some View {
        SettingsCard(
            title: "Elnät",
            footer: "Elnätskostnader används i totalpriset tillsammans med spotpris, elhandel och moms. Beloppen anges som på fakturan, inklusive moms."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Picker("Elnät", selection: $selectedDSOOrgNo) {
                    Text("Inget valt").tag("")
                    ForEach(dsoOptions) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Elnät")

                Picker("Säkring", selection: $fuseSize) {
                    ForEach(fuseSizes, id: \.self) { size in
                        Text("\(size) A").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Säkring")

                Toggle(EffectTariffCopy.toggleTitle, isOn: $includeHypotheticalEffectTariff)
                    .font(DS.Font.callout)
                    .accessibilityHint(EffectTariffCopy.explanation)

                Text(EffectTariffCopy.explanation)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let gridTariffError {
                    Label(gridTariffError, systemImage: "exclamationmark.triangle.fill")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let gridTariffSummary {
                    Label(gridTariffSummary, systemImage: "checkmark.circle.fill")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func currencyField(
        title: String,
        value: Binding<Double>,
        unit: String,
        field: Field
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Font.callout)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(DS.Font.callout.monospacedDigit())
                .frame(maxWidth: 110)
                .focused($focusedField, equals: field)
                .submitLabel(.done)
                .onSubmit {
                    flushPendingSave()
                }
                .accessibilityLabel(title)
            Text(unit)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .frame(width: 56, alignment: .leading)
                .accessibilityHidden(true)
        }
    }

    private var contractFooterText: String {
        switch contractType {
        case .spotPriceMarkup:
            return "Totalpriset följer spotpriset plus påslag, skatter, elnät och moms. Påslag, skatt och elnät anges som på fakturan, inklusive moms. Spotpriset hämtas utan moms."
        case .variableMonthlyPrice:
            return "Totalpriset använder ditt rörliga månadspris för elhandeln, inklusive moms."
        case .fixedPrice:
            return "Totalpriset använder ditt fasta avtalade pris för elhandeln, inklusive moms."
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
        includeHypotheticalEffectTariff = settings.includeHypotheticalEffectTariff
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
                    gridTariffError = "Hittade ingen tariff för valt elnät."
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
        if retailerMarkupOrePerKWh < 0 || retailerMonthlyFee < 0 || contractPriceOrePerKWh < 0 {
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
        }

        return next
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            AppSettingsView()
                .padding()
        }
        .background { AppCanvasBackground() }
    }
}
