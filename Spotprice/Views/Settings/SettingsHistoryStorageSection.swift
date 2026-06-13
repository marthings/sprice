//
//  SettingsHistoryStorageSection.swift
//  Spotprice
//

import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsHistoryStorageSection: View {
    @Bindable var settings: ConsumptionSettings

    @State private var historyStorageStatus = "Läser lokal historik..."
    @State private var historyExportDocument: HistoryCSVDocument?
    @State private var isExportingHistory = false
    @State private var isConfirmingHistoryDeletion = false

    var body: some View {
        Section {
            LabeledContent("Status", value: historyStorageStatus)

            Button("Uppdatera status") {
                loadHistoryStorageStatus()
            }

            Button("Exportera CSV") {
                exportLocalHistory()
            }

            Button("Rensa äldre än 24 månader") {
                pruneLocalHistory()
            }

            Button("Radera historik", role: .destructive) {
                isConfirmingHistoryDeletion = true
            }
        } header: {
            Text("Lokal historik")
        } footer: {
            Text("Historiken sparas lokalt i appgruppen och delas bara mellan appen, menyraden och widgeten på den här enheten.")
        }
        .onAppear {
            loadHistoryStorageStatus()
        }
        .onChange(of: settings.costProfile.priceArea) { _, _ in
            loadHistoryStorageStatus()
        }
        .fileExporter(
            isPresented: $isExportingHistory,
            document: historyExportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "sprice-history-\(settings.priceArea)"
        ) { result in
            if case .failure(let error) = result {
                historyStorageStatus = "Kunde inte exportera historik: \(error.userFacingMessage)"
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
            historyStorageStatus = "Kunde inte läsa historikstatus: \(error.userFacingMessage)"
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
            historyStorageStatus = "Kunde inte radera historik: \(error.userFacingMessage)"
        }
    }

    private func pruneLocalHistory() {
        do {
            let store = try SwiftDataEnergyHistoryStore()
            try store.pruneHistory(keepingRecentMonths: 24)
            loadHistoryStorageStatus()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            historyStorageStatus = "Kunde inte rensa historik: \(error.userFacingMessage)"
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