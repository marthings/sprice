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