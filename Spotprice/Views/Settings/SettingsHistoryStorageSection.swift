//
//  SettingsHistoryStorageSection.swift
//  Spotprice
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsHistoryStorageSection: View {
    @Bindable var settings: ConsumptionSettings

    @State private var historyStorageStatus = "Läser lokal historik..."
    @State private var historyExportDocument: HistoryCSVDocument?
    @State private var isExportingHistory = false
    @State private var isConfirmingHistoryDeletion = false
    @State private var isPreparingExport = false

    var body: some View {
        Section {
            LabeledContent("Status", value: historyStorageStatus)

            Button("Uppdatera status") {
                loadHistoryStorageStatus()
            }

            Button("Exportera CSV") {
                exportLocalHistory()
            }
            .disabled(isPreparingExport)

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
            let store = try EnergyHistoryStores.reader()
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
        isPreparingExport = true
        historyStorageStatus = "Exporterar historik..."
        let priceArea = settings.priceArea
        Task {
            defer { isPreparingExport = false }
            do {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("sprice-history-\(priceArea).csv", isDirectory: false)
                let writer = try EnergyHistoryStores.writer()
                try await writer.exportHistoryCSV(priceArea: priceArea, to: url)
                historyExportDocument = HistoryCSVDocument(url: url)
                isExportingHistory = true
                historyStorageStatus = "Historiken är redo att sparas."
            } catch {
                historyStorageStatus = "Kunde inte exportera historik: \(error.userFacingMessage)"
            }
        }
    }

    private func deleteLocalHistory() {
        Task {
            do {
                let writer = try EnergyHistoryStores.writer()
                try await writer.deleteAllHistory()
                historyStorageStatus = "Lokal historik är raderad."
                WidgetReload.timelines()
            } catch {
                historyStorageStatus = "Kunde inte radera historik: \(error.userFacingMessage)"
            }
        }
    }

    private func pruneLocalHistory() {
        Task {
            do {
                let writer = try EnergyHistoryStores.writer()
                try await writer.pruneHistory(keepingRecentMonths: 24)
                loadHistoryStorageStatus()
                WidgetReload.timelines()
            } catch {
                historyStorageStatus = "Kunde inte rensa historik: \(error.userFacingMessage)"
            }
        }
    }
}

struct HistoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    private let fileURL: URL?

    init(url: URL) {
        self.fileURL = url
    }

    init(configuration: ReadConfiguration) throws {
        self.fileURL = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if let fileURL {
            return try FileWrapper(url: fileURL, options: .immediate)
        }
        return FileWrapper(regularFileWithContents: Data())
    }
}