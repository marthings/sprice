//
//  SettingsView.swift
//  Spotprice
//
//  Settings window for consumption configuration

import SwiftUI
import UniformTypeIdentifiers
import WidgetKit
import OSLog

struct SettingsView: View {
    @Bindable var settings = ConsumptionSettings.shared
    @State private var selectedPriceArea = "SE3"
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var availableDSOs: [DSOOption] = []
    @State private var isLoadingDSOs = false
    @State private var dsoLoadError: String?
    @State private var historyStorageStatus = "Läser lokal historik..."
    @State private var historyExportDocument: HistoryCSVDocument?
    @State private var isExportingHistory = false
    @State private var isConfirmingHistoryDeletion = false

    private let priceAreas = ["SE1", "SE2", "SE3", "SE4"]
    private let gridTariffService = GridTariffService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    priceAreaSection
                    Divider()
                    estimateSection
                    Divider()
                    gridSection
                    Divider()
                    RetailContractSection(settings: settings)
                    Divider()
                    consumptionDataSection
                    Divider()
                    historyStorageSection
                    Divider()
                    advancedSection
                }
                .padding(DS.Spacing.lg)
            }

            // Sticky Footer
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 8) {
                    Group {
                        switch connectionStatus {
                        case .unknown:
                            if settings.isConfigured {
                                Label("Förbrukningsdata redo att verifieras", systemImage: "questionmark.circle.fill")
                                    .foregroundStyle(DS.Color.warning)
                            } else {
                                Label("Förbrukningsdata ej kopplad", systemImage: "bolt.horizontal.circle")
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        case .testing:
                            HStack(spacing: 4) {
                                ProgressView().scaleEffect(0.7)
                                Text("Testar...")
                            }
                            .foregroundStyle(DS.Color.secondary)
                        case .connected:
                            Label("Kopplad!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.success)
                        case .failed(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(DS.Color.danger)
                        }
                    }
                    .font(DS.Font.caption)

                    Spacer()

                    Button {
                        Task {
                            connectionStatus = .testing
                            do {
                                try await ConsumptionService().testConnection()
                                connectionStatus = .connected
                                
                                // Update cost profile confidence
                                settings.costProfile = settings.costProfile.updating(
                                    confidence: .providerConnected,
                                    source: .providerData
                                )
                                
                                // Clear any cached consumption to force fresh load
                                settings.cachedConsumption = nil
                                
                                // Trigger reload of consumption data via notification
                                NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                                
                                // Reload widgets
                                WidgetCenter.shared.reloadAllTimelines()
                                
                                AppLog.settings.info("Consumption provider verification succeeded")
                            } catch {
                                connectionStatus = .failed(error.localizedDescription)
                                AppLog.settings.error("Consumption provider verification failed: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    } label: {
                        Text("Verifiera")
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .font(DS.Font.bold(12))
                            .foregroundStyle(.white)
                            .background(DS.Color.brand, in: .rect(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(!settings.isConfigured || connectionStatus == .testing)
                }
                .padding(DS.Spacing.lg)
                .background(.background)
            }
        }
        .frame(width: DS.Size.settingsWidth, height: 520)
        .onAppear {
            selectedPriceArea = settings.costProfile.priceArea
            loadHistoryStorageStatus()
        }
        .fileExporter(
            isPresented: $isExportingHistory,
            document: historyExportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "sprice-history-\(settings.priceArea)"
        ) { result in
            if case .failure(let error) = result {
                historyStorageStatus = "Kunde inte exportera historik: \(error.localizedDescription)"
            }
        }
        .confirmationDialog(
            "Radera lokal historik?",
            isPresented: $isConfirmingHistoryDeletion
        ) {
            Button("Radera historik", role: .destructive) {
                deleteLocalHistory()
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Detta tar bort sparade priser, förbrukning och kostnadssummaries från den här enheten.")
        }
    }

    // MARK: - Sections

    private var priceAreaSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Elområde")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            Picker("", selection: $selectedPriceArea) {
                ForEach(priceAreas, id: \.self) { area in
                    Text(area).tag(area)
                }
            }
            .labelsHidden()
            .pickerStyle(.palette)
            .onChange(of: selectedPriceArea) { _, newValue in
                settings.costProfile = settings.costProfile.updating(priceArea: newValue)
                loadHistoryStorageStatus()
                WidgetCenter.shared.reloadAllTimelines()
            }

            Text("Välj ditt elområde i Sverige. Detta räcker för att visa en första kostnadsuppskattning.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var estimateSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Uppskattning")
                    .font(DS.Font.bold(12))
                    .foregroundStyle(.primary)

                Spacer()

                if let label = settings.costProfile.confidence.menuBarLabel {
                    Text(label)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(.quaternary.opacity(0.6), in: .capsule)
                }
            }

            settingSummaryRow(retailContractSummaryTitle, retailContractSummaryValue)
            settingSummaryRow("Elnät", settings.costProfile.gridMonthlyFee == nil && settings.costProfile.gridTransferOrePerKWh == nil ? "Ej inkluderat" : "Inkluderat")
            settingSummaryRow("Effektavgift", settings.costProfile.effectTariff == nil ? "Av" : "På")

            Text("Sprice visar ett pris baserat på tillgängliga uppgifter. Elnätskostnad ingår först när du lägger till dina elnätsuppgifter.")
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var gridSection: some View {
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

                    TextField("0", value: gridMonthlyFeeBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .help("Ange din fasta elnätsavgift per månad om tariffdata saknas eller avviker.")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Överföringsavgift (öre/kWh)")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)

                    TextField("0", value: gridTransferFeeBinding, format: .number)
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

    private var consumptionDataSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Förbrukningsdata")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            ProviderPicker(selectedProviderId: $settings.selectedProviderId)
                .onChange(of: settings.selectedProviderId) { _, newValue in
                    connectionStatus = .unknown
                    if newValue.isEmpty && settings.costProfile.confidence == .providerConnected {
                        settings.costProfile = settings.costProfile.applyingInferredConfidence(
                            preservingProviderConnected: false,
                            configuredSource: .userEntered
                        )
                    }
                }

            ProviderCredentialsSection(
                settings: settings,
                providerId: settings.selectedProviderId
            )

            Text("Detta är valfritt. Koppla en datakälla för månadstatistik, dygnsförbrukning och mer precisa insikter.")
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var historyStorageSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Lokal historik")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(historyStorageStatus)
                        .font(DS.Font.regular(11))
                        .foregroundStyle(.primary)
                    Text("Historiken sparas lokalt i appgruppen och delas bara mellan appen, menyraden och widgeten på den här enheten.")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                loadHistoryStorageStatus()
            } label: {
                Label("Uppdatera status", systemImage: "arrow.clockwise")
                    .font(DS.Font.medium(11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Color.info)

            HStack(spacing: DS.Spacing.md) {
                Button {
                    exportLocalHistory()
                } label: {
                    Label("Exportera CSV", systemImage: "square.and.arrow.up")
                        .font(DS.Font.medium(11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Color.info)

                Button(role: .destructive) {
                    isConfirmingHistoryDeletion = true
                } label: {
                    Label("Radera historik", systemImage: "trash")
                        .font(DS.Font.medium(11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Color.danger)
            }

            Button {
                pruneLocalHistory()
            } label: {
                Label("Rensa äldre än 24 månader", systemImage: "scissors")
                    .font(DS.Font.medium(11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Color.info)
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Avancerat")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            settingSummaryRow("Energiskatt", energyTaxText)
            settingSummaryRow("Elcertifikat", "1,75 öre/kWh")

            Toggle("Effektavgift", isOn: effectTariffEnabledBinding)
                .font(DS.Font.regular(11))

            if settings.costProfile.effectTariff != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Effektavgift (kr/kW/mån)")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(DS.Color.secondary)

                    TextField("0", value: effectTariffPriceBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .help("Ange bara detta om ditt elnätsbolag använder effektavgift.")
                }
            }

            Text("Effektavgift används bara om ditt elnätsbolag har det.")
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)

            Text(taxInfoText)
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var retailContractSummaryTitle: String {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            return "Elhandelsavgifter"
        case .variableMonthlyPrice:
            return "Rörligt månadspris"
        case .fixedPrice:
            return "Fast pris"
        }
    }

    private var retailContractSummaryValue: String {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            return "\(settings.costProfile.retailerMarkupOrePerKWh.formatted(.number.precision(.fractionLength(0...2)))) öre/kWh"
        case .variableMonthlyPrice, .fixedPrice:
            if let contractPrice = settings.costProfile.contractPriceOrePerKWh {
                return "\(contractPrice.formatted(.number.precision(.fractionLength(0...2)))) öre/kWh"
            }
            return "Ej angivet"
        }
    }

    private func settingSummaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(DS.Font.regular(11))
            Spacer()
            Text(value)
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var gridMonthlyFeeBinding: Binding<Double> {
        Binding(
            get: { settings.costProfile.gridMonthlyFee ?? 0 },
            set: { newValue in
                updateManualGridCosts(
                    monthlyFee: newValue,
                    transferFee: settings.costProfile.gridTransferOrePerKWh ?? 0
                )
            }
        )
    }

    private var gridTransferFeeBinding: Binding<Double> {
        Binding(
            get: { settings.costProfile.gridTransferOrePerKWh ?? 0 },
            set: { newValue in
                updateManualGridCosts(
                    monthlyFee: settings.costProfile.gridMonthlyFee ?? 0,
                    transferFee: newValue
                )
            }
        )
    }

    private var effectTariffEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.costProfile.effectTariff != nil },
            set: { isEnabled in
                if isEnabled {
                    updateEffectTariff(
                        monthlyPricePerKW: settings.costProfile.effectTariff?.monthlyPricePerKW ?? 0
                    )
                } else {
                    settings.costProfile = settings.costProfile
                        .settingEffectTariff(nil)
                        .applyingInferredConfidence()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        )
    }

    private var effectTariffPriceBinding: Binding<Double> {
        Binding(
            get: { settings.costProfile.effectTariff?.monthlyPricePerKW ?? 0 },
            set: { newValue in
                updateEffectTariff(monthlyPricePerKW: newValue)
            }
        )
    }

    private func updateManualGridCosts(monthlyFee: Double, transferFee: Double) {
        settings.costProfile = settings.costProfile.updating(
            gridCompanyId: settings.selectedDSOOrgNo.isEmpty ? settings.costProfile.gridCompanyId : settings.selectedDSOOrgNo,
            gridCompanyName: selectedDSOName,
            fuseSize: settings.fuseSize,
            gridMonthlyFee: monthlyFee,
            gridTransferOrePerKWh: transferFee,
            gridCostSource: .userEntered,
            confidence: .userConfigured,
            source: .userEntered
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func updateEffectTariff(monthlyPricePerKW: Double) {
        settings.costProfile = settings.costProfile.settingEffectTariff(
            EffectTariff(
                monthlyPricePerKW: monthlyPricePerKW,
                model: .manual,
                activeHours: .custom
            ),
            confidence: .userConfigured,
            source: .userEntered
        )
        WidgetCenter.shared.reloadAllTimelines()
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
    
    // MARK: - Computed Properties
    
    private var energyTaxText: String {
        // Jönköping has reduced energy tax from 2026
        if settings.selectedDSOOrgNo == "jonkoping" {
            return "45,0 öre/kWh"
        }
        return "54,88 öre/kWh"
    }
    
    private var taxInfoText: String {
        if settings.selectedDSOOrgNo == "jonkoping" {
            return "Energiskatt sänktes till 45 öre/kWh från januari 2026"
        }
        return "Svenska standardvärden 2025 (uppskattade värden i beräkningar)"
    }
    
    // MARK: - Helper Methods
    
    private func loadDSOs() async {
        isLoadingDSOs = true
        dsoLoadError = nil
        
        do {
            availableDSOs = try await gridTariffService.fetchAvailableDSOs()
        } catch {
            dsoLoadError = "Kunde inte ladda nätägare: \(error.localizedDescription)"
        }
        
        isLoadingDSOs = false
    }

    private func loadHistoryStorageStatus() {
        do {
            let store = try SwiftDataEnergyHistoryStore()
            let monthCount = try store.fetchMonthlySummaries(priceArea: settings.priceArea).count
            if monthCount == 0 {
                historyStorageStatus = "Ingen sparad historik för \(settings.priceArea) ännu."
            } else if monthCount == 1 {
                historyStorageStatus = "1 sparad månad för \(settings.priceArea)."
            } else {
                historyStorageStatus = "\(monthCount) sparade månader för \(settings.priceArea)."
            }
        } catch {
            historyStorageStatus = "Kunde inte läsa historikstatus: \(error.localizedDescription)"
        }
    }

    private func exportLocalHistory() {
        do {
            let store = try SwiftDataEnergyHistoryStore()
            let csv = try store.exportHistoryCSV(priceArea: settings.priceArea)
            historyExportDocument = HistoryCSVDocument(text: csv)
            isExportingHistory = true
        } catch {
            historyStorageStatus = "Kunde inte exportera historik: \(error.localizedDescription)"
        }
    }

    private func deleteLocalHistory() {
        do {
            let store = try SwiftDataEnergyHistoryStore()
            try store.deleteAllHistory()
            historyStorageStatus = "Lokal historik är raderad."
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            historyStorageStatus = "Kunde inte radera historik: \(error.localizedDescription)"
        }
    }

    private func pruneLocalHistory() {
        do {
            let store = try SwiftDataEnergyHistoryStore()
            try store.pruneHistory(keepingRecentMonths: 24)
            loadHistoryStorageStatus()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            historyStorageStatus = "Kunde inte rensa historik: \(error.localizedDescription)"
        }
    }
}

struct HistoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let text = String(data: data, encoding: .utf8) {
            self.text = text
        } else {
            self.text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

#Preview {
    SettingsView()
}
