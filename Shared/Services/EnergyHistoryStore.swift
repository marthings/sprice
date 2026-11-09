//
//  EnergyHistoryStore.swift
//  Spotprice
//
//  Local SwiftData persistence for historical electricity records.
//

import CoreData
import Foundation
import OSLog
import SwiftData

// MARK: - Energy History Store

@MainActor
protocol EnergyHistoryStore {
    func upsertRecords(_ drafts: [HistoricalEnergyRecordDraft]) throws
    func fetchRecords(in range: HistoricalEnergyDateRange, priceArea: String?) throws -> [HistoricalEnergyRecord]
    func fetchRecords(dayKey: String, priceArea: String?) throws -> [HistoricalEnergyRecord]
    func fetchRecords(monthKey: String, priceArea: String?) throws -> [HistoricalEnergyRecord]
    func fetchDailySummaries(monthKey: String, priceArea: String?) throws -> [HistoricalEnergySummaryValue]
    func fetchMonthlySummaries(priceArea: String?) throws -> [HistoricalEnergySummaryValue]
    func fetchMonthlySummaries(monthKey: String, priceArea: String?) throws -> [HistoricalEnergySummaryValue]
    func fetchTopCostDays(monthKey: String, priceArea: String?, limit: Int) throws -> [HistoricalEnergySummaryValue]
    func fetchTopConsumptionDays(monthKey: String, priceArea: String?, limit: Int) throws -> [HistoricalEnergySummaryValue]
    func spotPriceLookup(dayKey: String, priceArea: String) throws -> [Date: Double]
    func exportHistoryCSV(priceArea: String?) throws -> String
    func pruneHistory(keepingRecentMonths monthCount: Int) throws
    func deleteAllHistory() throws
}

// MARK: - Energy History Querying

struct EnergyHistoryMonthQueryResult {
    let months: [HistoricalEnergySummaryValue]
    let selectedMonth: HistoricalEnergySummaryValue?
    let dailySummaries: [HistoricalEnergySummaryValue]
    let topCostDays: [HistoricalEnergySummaryValue]
    let topConsumptionDays: [HistoricalEnergySummaryValue]
    let selectedMonthKey: String?
}

@MainActor
protocol EnergyHistoryQuerying {
    func loadMonthHistory(priceArea: String?, selectedMonthKey: String?) throws -> EnergyHistoryMonthQueryResult
    func loadCurrentMonthSummary(priceArea: String?, monthKey: String) throws -> HistoricalEnergySummaryValue?
    func loadDayIntervals(dayKey: String, priceArea: String?) throws -> [HistoricalEnergyIntervalValue]
}

@MainActor
enum EnergyHistoryStores {
    private static var cachedContainer: ModelContainer?
    private static var cachedReader: SwiftDataEnergyHistoryStore?
    private static var cachedWriter: EnergyHistoryWriter?

    static func container() throws -> ModelContainer {
        if let cachedContainer {
            return cachedContainer
        }
        let container = try EnergyHistoryModelContainer.makeLocalContainer()
        cachedContainer = container
        return container
    }

    static func reader() throws -> SwiftDataEnergyHistoryStore {
        if let cachedReader {
            return cachedReader
        }
        let store = SwiftDataEnergyHistoryStore(container: try container())
        cachedReader = store
        return store
    }

    static func writer() throws -> EnergyHistoryWriter {
        if let cachedWriter {
            return cachedWriter
        }
        let writer = EnergyHistoryWriter(modelContainer: try container())
        cachedWriter = writer
        return writer
    }
}

@MainActor
final class EnergyHistoryQueryService: EnergyHistoryQuerying {
    private let store: (any EnergyHistoryStore)?

    init(store: (any EnergyHistoryStore)? = nil) {
        self.store = store
    }

    func loadMonthHistory(priceArea: String?, selectedMonthKey: String?) throws -> EnergyHistoryMonthQueryResult {
        let store = try resolvedStore()
        let months = uniqueBestMonthlySummaries(try store.fetchMonthlySummaries(priceArea: priceArea))
        let resolvedMonthKey = selectedMonthKey ?? EnergyHistoryKey.preferredMonthKey(from: months)
        let dailySummaries: [HistoricalEnergySummaryValue]

        if let resolvedMonthKey {
            dailySummaries = try store.fetchDailySummaries(monthKey: resolvedMonthKey, priceArea: priceArea)
                .sorted { $0.periodStart < $1.periodStart }
        } else {
            dailySummaries = []
        }

        return EnergyHistoryMonthQueryResult(
            months: months,
            selectedMonth: months.first { $0.periodKey == resolvedMonthKey },
            dailySummaries: dailySummaries,
            topCostDays: [],
            topConsumptionDays: [],
            selectedMonthKey: resolvedMonthKey
        )
    }

    func loadCurrentMonthSummary(priceArea: String?, monthKey: String) throws -> HistoricalEnergySummaryValue? {
        let store = try resolvedStore()
        return try store.fetchMonthlySummaries(monthKey: monthKey, priceArea: priceArea)
            .max { lhs, rhs in rhs.isPreferred(over: lhs) }
    }

    func loadDayIntervals(dayKey: String, priceArea: String?) throws -> [HistoricalEnergyIntervalValue] {
        let store = try resolvedStore()
        return Self.preferredIntervals(from: try store.fetchRecords(dayKey: dayKey, priceArea: priceArea))
    }

    private func resolvedStore() throws -> any EnergyHistoryStore {
        if let store {
            return store
        }
        return try EnergyHistoryStores.reader()
    }

    private func uniqueBestMonthlySummaries(_ summaries: [HistoricalEnergySummaryValue]) -> [HistoricalEnergySummaryValue] {
        summaries.bestSummaries(groupedBy: \.periodKey)
            .sorted { $0.periodStart > $1.periodStart }
    }

    static func preferredIntervals(from records: [HistoricalEnergyRecord]) -> [HistoricalEnergyIntervalValue] {
        Dictionary(grouping: records, by: \.intervalStart)
            .values
            .compactMap { group -> HistoricalEnergyIntervalValue? in
                guard let preferred = group.max(by: { intervalPreference($0) < intervalPreference($1) }) else {
                    return nil
                }
                return preferred.intervalValue()
            }
            .sorted { $0.intervalStart < $1.intervalStart }
    }

    private static func intervalPreference(_ record: HistoricalEnergyRecord) -> Int {
        var score = 0
        if record.consumptionKWh != nil { score += 4 }
        if record.totalCostSEK != nil { score += 2 }
        if record.energyCostSEK != nil { score += 1 }
        return score
    }
}

@MainActor
final class StaticEnergyHistoryQueryService: EnergyHistoryQuerying {
    private let monthHistory: EnergyHistoryMonthQueryResult
    private let currentMonthSummary: HistoricalEnergySummaryValue?
    private let dayIntervals: [HistoricalEnergyIntervalValue]

    init(
        monthHistory: EnergyHistoryMonthQueryResult,
        currentMonthSummary: HistoricalEnergySummaryValue? = nil,
        dayIntervals: [HistoricalEnergyIntervalValue] = []
    ) {
        self.monthHistory = monthHistory
        self.currentMonthSummary = currentMonthSummary
        self.dayIntervals = dayIntervals
    }

    func loadMonthHistory(priceArea: String?, selectedMonthKey: String?) throws -> EnergyHistoryMonthQueryResult {
        monthHistory
    }

    func loadCurrentMonthSummary(priceArea: String?, monthKey: String) throws -> HistoricalEnergySummaryValue? {
        currentMonthSummary
    }

    func loadDayIntervals(dayKey: String, priceArea: String?) throws -> [HistoricalEnergyIntervalValue] {
        dayIntervals
    }
}

// MARK: - Errors

enum EnergyHistoryStoreError: LocalizedError {
    case missingAppGroupContainer(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAppGroupContainer(let identifier):
            return "App Group container saknas för \(identifier). Kontrollera target-entitlements."
        case .exportFailed(let reason):
            return "Kunde inte exportera historik: \(reason)"
        }
    }
}

// MARK: - SwiftData Model Container

/// Current on-disk schema. History is a refillable cache, so incompatible stores
/// are deleted and rebuilt instead of migrated.
///
/// 7dfbb6c wrote version 1.0.0 with `Schema(CurrentSchema.models, version:)` and
/// no `#Unique` / `#Index`. 009eb2b then pointed both 1.0.0 and 1.1.0 at the
/// current model types (which now have those macros), so the shipped store's
/// hashes never matched the source model and the custom stage never ran.
enum EnergyHistorySchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 2, 0)

    static var models: [any PersistentModel.Type] {
        [
            HistoricalEnergyRecord.self,
            HistoricalDailyEnergySummary.self,
            HistoricalMonthlyEnergySummary.self,
            HistoricalCostProfileSnapshotRecord.self
        ]
    }
}

enum EnergyHistoryModelContainer {
    private static let storeGenerationKey = "energyHistory.storeGeneration"
    /// Bumped when the on-disk schema cannot open stores written before 1.2.0.
    /// History is a refillable cache. Adding `snapshotHash` plus a snapshot entity
    /// is not a safe VersionedSchema lightweight migration without duplicating the
    /// previous model types (that approach crashed on launch in 1.1.0), so existing
    /// stores are deleted and rebuilt. If opening still fails, we fall back to in-memory.
    private static let currentStoreGeneration = 3

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: EnergyHistoryConstants.appGroupIdentifier) ?? .standard
    }

    static func makeLocalContainer() throws -> ModelContainer {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: EnergyHistoryConstants.appGroupIdentifier) != nil else {
            throw EnergyHistoryStoreError.missingAppGroupContainer(EnergyHistoryConstants.appGroupIdentifier)
        }

        let schema = Schema(versionedSchema: EnergyHistorySchema.self)
        let configuration = ModelConfiguration(
            EnergyHistoryConstants.storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(EnergyHistoryConstants.appGroupIdentifier),
            // Keep local-only until sync has explicit UI, entitlements, migration, and conflict handling.
            cloudKitDatabase: .none
        )

        if shouldResetPersistentStore(at: configuration.url) {
            resetPersistentStore(configuration, reason: "incompatible history store from a previous schema")
        }

        do {
            return try openPersistentStore(schema: schema, configuration: configuration)
        } catch {
            AppLog.history.error("History store failed to open: \(error.localizedDescription, privacy: .public)")
            resetPersistentStore(configuration, reason: error.localizedDescription)
            do {
                return try openPersistentStore(schema: schema, configuration: configuration)
            } catch {
                AppLog.history.error("History store rebuild failed: \(error.localizedDescription, privacy: .public). Using an in-memory store for this launch.")
                return try makeInMemoryContainer()
            }
        }
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: EnergyHistorySchema.self)
        let configuration = ModelConfiguration(
            EnergyHistoryConstants.storeName,
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func openPersistentStore(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        markStoreCompatible()
        return container
    }

    private static func shouldResetPersistentStore(at url: URL) -> Bool {
        let storedGeneration = defaults.integer(forKey: storeGenerationKey)
        if storedGeneration >= currentStoreGeneration {
            return storeMetadataLooksUnreadable(at: url)
        }
        return storeFileExists(at: url)
    }

    private static func storeFileExists(at url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: path)
            || FileManager.default.fileExists(atPath: path + "-wal")
    }

    private static func storeMetadataLooksUnreadable(at url: URL) -> Bool {
        guard storeFileExists(at: url) else {
            return false
        }
        do {
            _ = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: url)
            return false
        } catch {
            AppLog.history.error("History store metadata unreadable: \(error.localizedDescription, privacy: .public)")
            return true
        }
    }

    private static func resetPersistentStore(_ configuration: ModelConfiguration, reason: String) {
        AppLog.history.error("Resetting history store: \(reason, privacy: .public)")
        let url = configuration.url
        do {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try coordinator.destroyPersistentStore(at: url, type: .sqlite)
        } catch {
            AppLog.history.error("destroyPersistentStore failed: \(error.localizedDescription, privacy: .public)")
        }
        deleteStoreFiles(around: url)
        WidgetHistorySummaryCache.clear()
        EnergyHistoryBackfillController.resetAfterStoreRebuild()
        defaults.removeObject(forKey: storeGenerationKey)
    }

    private static func deleteStoreFiles(around url: URL) {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let prefix = url.lastPathComponent
        let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [url]
        for file in contents where file.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: file)
        }
    }

    private static func markStoreCompatible() {
        defaults.set(currentStoreGeneration, forKey: storeGenerationKey)
    }
}

// MARK: - SwiftData Energy History Store

@MainActor
final class SwiftDataEnergyHistoryStore: EnergyHistoryStore {
    private let context: ModelContext
    private let calendar: Calendar

    init(container: ModelContainer, calendar: Calendar? = nil) {
        self.context = ModelContext(container)
        self.calendar = calendar ?? .energyHistory
    }

    convenience init() throws {
        try self.init(container: EnergyHistoryStores.container())
    }

    func upsertRecords(_ drafts: [HistoricalEnergyRecordDraft]) throws {
        try EnergyHistoryWriting.upsertRecords(drafts, context: context, calendar: calendar)
    }

    func fetchRecords(in range: HistoricalEnergyDateRange, priceArea: String? = nil) throws -> [HistoricalEnergyRecord] {
        let start = range.start
        let end = range.end
        let descriptor: FetchDescriptor<HistoricalEnergyRecord>

        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.intervalStart >= start && record.intervalStart < end && record.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.intervalStart >= start && record.intervalStart < end
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        }

        return try context.fetch(descriptor)
    }

    func fetchRecords(dayKey: String, priceArea: String? = nil) throws -> [HistoricalEnergyRecord] {
        let descriptor: FetchDescriptor<HistoricalEnergyRecord>

        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.dayKey == dayKey && record.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.dayKey == dayKey
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        }

        return try context.fetch(descriptor)
    }

    func fetchRecords(monthKey: String, priceArea: String? = nil) throws -> [HistoricalEnergyRecord] {
        let descriptor: FetchDescriptor<HistoricalEnergyRecord>

        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.monthKey == monthKey && record.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.monthKey == monthKey
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        }

        return try context.fetch(descriptor)
    }

    func fetchDailySummaries(monthKey: String, priceArea: String? = nil) throws -> [HistoricalEnergySummaryValue] {
        let descriptor: FetchDescriptor<HistoricalDailyEnergySummary>

        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalDailyEnergySummary> { summary in
                    summary.monthKey == monthKey && summary.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalDailyEnergySummary.date)]
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalDailyEnergySummary> { summary in
                    summary.monthKey == monthKey
                },
                sortBy: [SortDescriptor(\HistoricalDailyEnergySummary.date)]
            )
        }

        let allSummaries = try context.fetch(descriptor).map { $0.summaryValue() }
        return uniqueBestDailySummaries(allSummaries)
    }

    func fetchMonthlySummaries(priceArea: String? = nil) throws -> [HistoricalEnergySummaryValue] {
        var descriptor: FetchDescriptor<HistoricalMonthlyEnergySummary>

        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                    summary.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalMonthlyEnergySummary.monthStart, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor(
                sortBy: [SortDescriptor(\HistoricalMonthlyEnergySummary.monthStart, order: .reverse)]
            )
        }
        descriptor.fetchLimit = 128

        return try context.fetch(descriptor).map { $0.summaryValue() }
    }

    func fetchMonthlySummaries(monthKey: String, priceArea: String? = nil) throws -> [HistoricalEnergySummaryValue] {
        try EnergyHistoryWriting.fetchMonthlySummaries(
            monthKey: monthKey,
            priceArea: priceArea,
            context: context
        )
    }

    func fetchTopCostDays(
        monthKey: String,
        priceArea: String? = nil,
        limit: Int = 3
    ) throws -> [HistoricalEnergySummaryValue] {
        try fetchTopDays(monthKey: monthKey, priceArea: priceArea, limit: limit) { summary in
            summary.totalCostSEK
        }
    }

    func fetchTopConsumptionDays(
        monthKey: String,
        priceArea: String? = nil,
        limit: Int = 3
    ) throws -> [HistoricalEnergySummaryValue] {
        try fetchTopDays(monthKey: monthKey, priceArea: priceArea, limit: limit) { summary in
            summary.totalConsumptionKWh
        }
    }

    func spotPriceLookup(dayKey: String, priceArea: String) throws -> [Date: Double] {
        try EnergyHistoryWriting.spotPriceLookup(dayKey: dayKey, priceArea: priceArea, context: context)
    }

    func exportHistoryCSV(priceArea: String? = nil) throws -> String {
        let records = try fetchAllRecords(priceArea: priceArea)
        let formatter = ISO8601DateFormatter()
        var rows = [[
            "interval_start",
            "interval_end",
            "day",
            "month",
            "price_area",
            "provider_id",
            "source",
            "confidence",
            "spot_price_ore_per_kwh",
            "consumption_kwh",
            "energy_cost_sek",
            "grid_cost_sek",
            "tax_cost_sek",
            "vat_cost_sek",
            "total_cost_sek"
        ].joined(separator: ",")]

        rows.append(contentsOf: records.map { record in
            [
                formatter.string(from: record.intervalStart),
                formatter.string(from: record.intervalEnd),
                record.dayKey,
                record.monthKey,
                record.priceArea,
                record.providerID ?? "",
                record.source.rawValue,
                record.confidence.rawValue,
                csvNumber(record.spotPriceOrePerKWh),
                csvNumber(record.consumptionKWh),
                csvNumber(record.energyCostSEK),
                csvNumber(record.gridCostSEK),
                csvNumber(record.taxCostSEK),
                csvNumber(record.vatCostSEK),
                csvNumber(record.totalCostSEK)
            ]
            .map(csvEscape)
            .joined(separator: ",")
        })

        return rows.joined(separator: "\n")
    }

    func deleteAllHistory() throws {
        try deleteAll(HistoricalEnergyRecord.self)
        try deleteAll(HistoricalDailyEnergySummary.self)
        try deleteAll(HistoricalMonthlyEnergySummary.self)
        try deleteAll(HistoricalCostProfileSnapshotRecord.self)
        try context.save()
        WidgetHistorySummaryCache.clear()
    }

    func pruneHistory(keepingRecentMonths monthCount: Int) throws {
        guard monthCount > 0,
              let cutoff = calendar.date(byAdding: .month, value: -monthCount + 1, to: calendar.startOfDay(for: Date())),
              let cutoffMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: cutoff)) else {
            return
        }

        try deleteRecords(before: cutoffMonthStart)
        try deleteDailySummaries(before: cutoffMonthStart)
        try deleteMonthlySummaries(before: cutoffMonthStart)
        try context.save()
        try rebuildWidgetSummaryCache()
    }

    private func fetchRecord(deduplicationKey: String) throws -> HistoricalEnergyRecord? {
        var descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalEnergyRecord> { record in
                record.deduplicationKey == deduplicationKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchAllRecords(priceArea: String?) throws -> [HistoricalEnergyRecord] {
        let descriptor: FetchDescriptor<HistoricalEnergyRecord>

        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        } else {
            descriptor = FetchDescriptor(
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        }

        return try context.fetch(descriptor)
    }

    private func deleteRecords(before cutoff: Date) throws {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalEnergyRecord> { record in
                record.intervalStart < cutoff
            }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
    }

    private func deleteDailySummaries(before cutoff: Date) throws {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalDailyEnergySummary> { summary in
                summary.date < cutoff
            }
        )
        for summary in try context.fetch(descriptor) {
            context.delete(summary)
        }
    }

    private func deleteMonthlySummaries(before cutoff: Date) throws {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                summary.monthStart < cutoff
            }
        )
        for summary in try context.fetch(descriptor) {
            context.delete(summary)
        }
    }

    private func rebuildWidgetSummaryCache() throws {
        let summaries = try fetchMonthlySummaries(priceArea: nil)
        let groupedByPriceAreaAndMonth = Dictionary(grouping: summaries) { summary in
            SummaryCacheKey(monthKey: summary.periodKey, priceArea: summary.priceArea)
        }
        let widgetSummaries = groupedByPriceAreaAndMonth.compactMap { _, summaries in
            bestWidgetSummary(from: summaries).map { WidgetHistorySummary(summary: $0) }
        }
        WidgetHistorySummaryCache.replaceAll(widgetSummaries)
    }

    private func csvNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        return AppFormatters.csvNumber(value)
    }

    private func csvNumber(_ value: Double) -> String {
        AppFormatters.csvNumber(value)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func rebuildDailySummaries(dayKeys: Set<String>, updatedAt: Date) throws {
        for dayKey in dayKeys {
            let records = try fetchRecords(dayKey: dayKey)
            let groupedRecords = Dictionary(grouping: records) { record in
                SummaryGroupKey(priceArea: record.priceArea, providerID: record.providerID)
            }

            for (groupKey, groupRecords) in groupedRecords {
                guard let firstRecord = groupRecords.first else { continue }
                let summaryKey = EnergyHistoryKey.summaryKey(
                    periodKey: dayKey,
                    priceArea: groupKey.priceArea,
                    providerID: groupKey.providerID
                )
                let stats = makeSummaryStats(from: groupRecords)
                let dayStart = calendar.startOfDay(for: firstRecord.intervalStart)

                if let existingSummary = try fetchDailySummary(summaryKey: summaryKey) {
                    existingSummary.update(
                        providerID: groupKey.providerID,
                        date: dayStart,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    )
                } else {
                    context.insert(HistoricalDailyEnergySummary(
                        summaryKey: summaryKey,
                        dayKey: dayKey,
                        monthKey: firstRecord.monthKey,
                        date: dayStart,
                        priceArea: groupKey.priceArea,
                        providerID: groupKey.providerID,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    ))
                }
            }
        }
    }

    private func rebuildMonthlySummaries(monthKeys: Set<String>, updatedAt: Date) throws {
        for monthKey in monthKeys {
            let records = try fetchRecords(monthKey: monthKey)
            let groupedRecords = Dictionary(grouping: records) { record in
                SummaryGroupKey(priceArea: record.priceArea, providerID: record.providerID)
            }

            for (groupKey, groupRecords) in groupedRecords {
                guard let firstRecord = groupRecords.first else { continue }
                let summaryKey = EnergyHistoryKey.summaryKey(
                    periodKey: monthKey,
                    priceArea: groupKey.priceArea,
                    providerID: groupKey.providerID
                )
                let stats = makeSummaryStats(from: groupRecords)
                let dayCount = Set(groupRecords.map(\.dayKey)).count
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: firstRecord.intervalStart)) ?? firstRecord.intervalStart

                if let existingSummary = try fetchMonthlySummary(summaryKey: summaryKey) {
                    existingSummary.update(
                        providerID: groupKey.providerID,
                        monthStart: monthStart,
                        dayCount: dayCount,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    )
                } else {
                    context.insert(HistoricalMonthlyEnergySummary(
                        summaryKey: summaryKey,
                        monthKey: monthKey,
                        monthStart: monthStart,
                        priceArea: groupKey.priceArea,
                        providerID: groupKey.providerID,
                        dayCount: dayCount,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    ))
                }
            }
        }
    }

    private func fetchDailySummary(summaryKey: String) throws -> HistoricalDailyEnergySummary? {
        var descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalDailyEnergySummary> { summary in
                summary.summaryKey == summaryKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchMonthlySummary(summaryKey: String) throws -> HistoricalMonthlyEnergySummary? {
        var descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                summary.summaryKey == summaryKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func updateWidgetSummaryCache(monthKeys: Set<String>, updatedAt: Date) throws {
        for monthKey in monthKeys {
            let summaries = try fetchDailyBackedMonthlySummaries(monthKey: monthKey)
            let groupedByPriceArea = Dictionary(grouping: summaries, by: \.priceArea)

            for (_, priceAreaSummaries) in groupedByPriceArea {
                guard let summary = bestWidgetSummary(from: priceAreaSummaries) else { continue }
                WidgetHistorySummaryCache.store(WidgetHistorySummary(summary: summary, updatedAt: updatedAt))
            }
        }
    }

    private func fetchDailyBackedMonthlySummaries(monthKey: String) throws -> [HistoricalEnergySummaryValue] {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                summary.monthKey == monthKey
            },
            sortBy: [SortDescriptor(\HistoricalMonthlyEnergySummary.monthStart)]
        )
        return try context.fetch(descriptor).map { $0.summaryValue() }
    }

    private func bestWidgetSummary(from summaries: [HistoricalEnergySummaryValue]) -> HistoricalEnergySummaryValue? {
        summaries.max { lhs, rhs in rhs.isPreferred(over: lhs) }
    }

    private func fetchTopDays(
        monthKey: String,
        priceArea: String?,
        limit: Int,
        value: (HistoricalEnergySummaryValue) -> Double?
    ) throws -> [HistoricalEnergySummaryValue] {
        guard limit > 0 else { return [] }

        return Array(
            try fetchDailySummaries(monthKey: monthKey, priceArea: priceArea)
                .filter { value($0) != nil }
                .sorted { lhs, rhs in
                    let lhsValue = value(lhs) ?? 0
                    let rhsValue = value(rhs) ?? 0

                    if lhsValue == rhsValue {
                        return lhs.periodStart < rhs.periodStart
                    }
                    return lhsValue > rhsValue
                }
                .prefix(limit)
        )
    }

    private func uniqueBestDailySummaries(_ summaries: [HistoricalEnergySummaryValue]) -> [HistoricalEnergySummaryValue] {
        summaries.bestSummaries(groupedBy: \.periodKey)
    }

    private func makeSummaryStats(from records: [HistoricalEnergyRecord]) -> SummaryStats {
        let intervalCount = records.count
        let measuredRecords = records.filter { $0.consumptionKWh != nil }
        let totalConsumption = measuredRecords.reduce(0) { $0 + ($1.consumptionKWh ?? 0) }
        let totalCosts = records.compactMap(\.totalCostSEK)
        let spotPrices = records.map(\.spotPriceOrePerKWh)

        return SummaryStats(
            intervalCount: intervalCount,
            measuredIntervalCount: measuredRecords.count,
            totalConsumptionKWh: measuredRecords.isEmpty ? nil : totalConsumption,
            totalCostSEK: totalCosts.isEmpty ? nil : totalCosts.reduce(0, +),
            averageSpotPriceOrePerKWh: spotPrices.isEmpty ? nil : spotPrices.reduce(0, +) / Double(spotPrices.count),
            minSpotPriceOrePerKWh: spotPrices.min(),
            maxSpotPriceOrePerKWh: spotPrices.max(),
            confidence: summaryConfidence(for: records)
        )
    }

    private func summaryConfidence(for records: [HistoricalEnergyRecord]) -> HistoricalEnergyConfidence {
        guard !records.isEmpty else { return .priceOnly }

        let confidences = Set(records.map(\.confidence))
        if confidences == [.measured] {
            return .measured
        }
        if confidences.contains(.measured) || confidences.contains(.partial) {
            return .partial
        }
        if confidences.contains(.recalculated) {
            return .recalculated
        }
        if confidences.contains(.estimated) {
            return .estimated
        }
        return .priceOnly
    }

    private func deleteAll<T: PersistentModel>(_ modelType: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let records = try context.fetch(descriptor)
        for record in records {
            context.delete(record)
        }
    }
}

@ModelActor
actor EnergyHistoryWriter {
    func upsertRecords(_ drafts: [HistoricalEnergyRecordDraft]) throws {
        try EnergyHistoryWriting.upsertRecords(drafts, context: modelContext, calendar: .energyHistory)
    }

    func pruneHistory(keepingRecentMonths monthCount: Int) throws {
        try EnergyHistoryWriting.pruneHistory(
            keepingRecentMonths: monthCount,
            context: modelContext,
            calendar: .energyHistory
        )
    }

    func deleteAllHistory() throws {
        try EnergyHistoryWriting.deleteAllHistory(context: modelContext)
    }

    func repriceMeasuredRecords(
        lookups: [String: [Date: Double]],
        fallbackProfile: CostProfile
    ) throws -> Int {
        try EnergyHistoryWriting.repriceMeasuredRecords(
            lookups: lookups,
            fallbackProfile: fallbackProfile,
            context: modelContext,
            calendar: .energyHistory
        )
    }

    func exportHistoryCSV(priceArea: String?, to url: URL) throws {
        try EnergyHistoryWriting.exportHistoryCSV(priceArea: priceArea, to: url, context: modelContext)
    }
}

nonisolated enum EnergyHistoryWriting {
    nonisolated static func upsertRecords(
        _ drafts: [HistoricalEnergyRecordDraft],
        context: ModelContext,
        calendar: Calendar
    ) throws {
        guard !drafts.isEmpty else { return }

        let now = Date()
        let snapshotData = drafts.lazy.compactMap(\.costProfileSnapshot).first.flatMap(
            HistoricalCostProfileSnapshot.encodedData
        )
        let snapshotHash = snapshotData.map(HistoricalCostProfileSnapshot.hash(of:))
        if let snapshotData, let snapshotHash {
            try upsertSnapshotRecord(snapshotHash: snapshotHash, data: snapshotData, context: context)
        }
        var existingByKey = try fetchExistingRecords(for: drafts, context: context)
        var affectedDayKeys = Set<String>()
        var affectedMonthKeys = Set<String>()

        for draft in drafts {
            affectedDayKeys.insert(draft.dayKey)
            affectedMonthKeys.insert(draft.monthKey)

            if let existingRecord = existingByKey[draft.deduplicationKey] {
                existingRecord.update(
                    from: draft,
                    snapshotData: snapshotData,
                    snapshotHash: snapshotHash,
                    updatedAt: now
                )
            } else {
                let record = draft.makeRecord(
                    createdAt: now,
                    snapshotData: snapshotData,
                    snapshotHash: snapshotHash
                )
                context.insert(record)
                existingByKey[draft.deduplicationKey] = record
            }
        }

        try rebuildDailySummaries(dayKeys: affectedDayKeys, updatedAt: now, context: context, calendar: calendar)
        try rebuildMonthlySummaries(monthKeys: affectedMonthKeys, updatedAt: now, context: context, calendar: calendar)
        try context.save()
        try updateWidgetSummaryCache(monthKeys: affectedMonthKeys, updatedAt: now, context: context)
    }

    nonisolated static func exportHistoryCSV(
        priceArea: String?,
        to url: URL,
        context: ModelContext
    ) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let stream = OutputStream(url: url, append: false) else {
            throw EnergyHistoryStoreError.exportFailed(url.path)
        }
        stream.open()
        defer { stream.close() }

        let header = [
            "interval_start",
            "interval_end",
            "day",
            "month",
            "price_area",
            "provider_id",
            "source",
            "confidence",
            "spot_price_ore_per_kwh",
            "consumption_kwh",
            "energy_cost_sek",
            "grid_cost_sek",
            "tax_cost_sek",
            "vat_cost_sek",
            "total_cost_sek"
        ].joined(separator: ",") + "\n"
        try writeCSV(header, to: stream)

        let formatter = ISO8601DateFormatter()
        let months = try context.fetch(
            FetchDescriptor<HistoricalMonthlyEnergySummary>(
                sortBy: [SortDescriptor(\HistoricalMonthlyEnergySummary.monthStart)]
            )
        )
        let monthKeys: [String]
        if months.isEmpty {
            monthKeys = [""]
        } else {
            var seen = Set<String>()
            monthKeys = months.compactMap { summary in
                if let priceArea, summary.priceArea != priceArea { return nil }
                if seen.contains(summary.monthKey) { return nil }
                seen.insert(summary.monthKey)
                return summary.monthKey
            }
        }

        for monthKey in monthKeys {
            let records = try fetchRecords(
                monthKey: monthKey.isEmpty ? nil : monthKey,
                priceArea: priceArea,
                context: context
            )
            for record in records {
                let row = [
                    formatter.string(from: record.intervalStart),
                    formatter.string(from: record.intervalEnd),
                    record.dayKey,
                    record.monthKey,
                    record.priceArea,
                    record.providerID ?? "",
                    record.source.rawValue,
                    record.confidence.rawValue,
                    csvNumber(record.spotPriceOrePerKWh),
                    csvNumber(record.consumptionKWh),
                    csvNumber(record.energyCostSEK),
                    csvNumber(record.gridCostSEK),
                    csvNumber(record.taxCostSEK),
                    csvNumber(record.vatCostSEK),
                    csvNumber(record.totalCostSEK)
                ]
                .map(csvEscape)
                .joined(separator: ",") + "\n"
                try writeCSV(row, to: stream)
            }
        }
    }

    nonisolated static func spotPriceLookup(
        dayKey: String,
        priceArea: String,
        context: ModelContext
    ) throws -> [Date: Double] {
        let records = try fetchRecords(dayKey: dayKey, context: context)
        var map: [Date: Double] = [:]
        map.reserveCapacity(records.count)
        for record in records where record.priceArea == priceArea && record.spotPriceOrePerKWh != 0 {
            if record.source == .spotPrice || map[record.intervalStart] == nil {
                map[record.intervalStart] = record.spotPriceOrePerKWh
            }
        }
        return map
    }

    nonisolated static func fetchMonthlySummaries(
        monthKey: String,
        priceArea: String?,
        context: ModelContext
    ) throws -> [HistoricalEnergySummaryValue] {
        var descriptor: FetchDescriptor<HistoricalMonthlyEnergySummary>
        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                    summary.monthKey == monthKey && summary.priceArea == priceArea
                }
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                    summary.monthKey == monthKey
                }
            )
        }
        descriptor.fetchLimit = 8
        return try context.fetch(descriptor).map { $0.summaryValue() }
    }

    nonisolated static func pruneHistory(
        keepingRecentMonths monthCount: Int,
        context: ModelContext,
        calendar: Calendar
    ) throws {
        guard monthCount > 0,
              let cutoff = calendar.date(byAdding: .month, value: -monthCount + 1, to: calendar.startOfDay(for: Date())),
              let cutoffMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: cutoff)) else {
            return
        }

        try deleteRecords(before: cutoffMonthStart, context: context)
        try deleteDailySummaries(before: cutoffMonthStart, context: context)
        try deleteMonthlySummaries(before: cutoffMonthStart, context: context)
        try context.save()
        try rebuildWidgetSummaryCache(context: context)
    }

    nonisolated static func deleteAllHistory(context: ModelContext) throws {
        try deleteAll(HistoricalEnergyRecord.self, context: context)
        try deleteAll(HistoricalDailyEnergySummary.self, context: context)
        try deleteAll(HistoricalMonthlyEnergySummary.self, context: context)
        try deleteAll(HistoricalCostProfileSnapshotRecord.self, context: context)
        try context.save()
        WidgetHistorySummaryCache.clear()
    }

    nonisolated static func repriceMeasuredRecords(
        lookups: [String: [Date: Double]],
        fallbackProfile: CostProfile,
        context: ModelContext,
        calendar: Calendar
    ) throws -> Int {
        let records = try context.fetch(FetchDescriptor<HistoricalEnergyRecord>())
        let service = TotalCostService.shared
        var changedDays = Set<String>()
        var changedMonths = Set<String>()
        var updated = 0

        for record in records {
            guard let consumption = record.consumptionKWh, consumption > 0 else { continue }
            let lookupKey = "\(record.priceArea)|\(record.dayKey)"
            guard let lookup = lookups[lookupKey] else { continue }
            let hoursInPeriod = max(record.intervalEnd.timeIntervalSince(record.intervalStart) / 3600, 1 / 60)
            guard let spot = SpotPriceMatching.price(
                for: record.intervalStart,
                hoursInPeriod: hoursInPeriod,
                lookup: lookup,
                calendar: calendar
            ) else {
                continue
            }

            let profile: CostProfile
            if let snapshotProfile = try costProfile(for: record, context: context) {
                profile = snapshotProfile
            } else {
                profile = fallbackProfile
            }

            let cost = service.calculateTotalCost(
                kWh: consumption,
                spotPriceOre: spot,
                profile: profile,
                hoursInPeriod: hoursInPeriod
            )
            let spotChanged = abs(record.spotPriceOrePerKWh - spot) > 0.0001
            let totalChanged = abs((record.totalCostSEK ?? 0) - cost.totalKr) > 0.0001
            guard spotChanged || totalChanged else { continue }

            record.spotPriceOrePerKWh = spot
            record.energyCostSEK = cost.providerTotalKr
            record.gridCostSEK = cost.gridTotalKr
            record.taxCostSEK = cost.taxesAndFeesKr
            record.vatCostSEK = cost.vatKr
            record.totalCostSEK = cost.totalKr
            record.updatedAt = Date()
            changedDays.insert(record.dayKey)
            changedMonths.insert(record.monthKey)
            updated += 1
        }

        if updated > 0 {
            let now = Date()
            try rebuildDailySummaries(dayKeys: changedDays, updatedAt: now, context: context, calendar: calendar)
            try rebuildMonthlySummaries(monthKeys: changedMonths, updatedAt: now, context: context, calendar: calendar)
            try context.save()
            try updateWidgetSummaryCache(monthKeys: changedMonths, updatedAt: now, context: context)
        }
        return updated
    }

    nonisolated private static func fetchExistingRecords(
        for drafts: [HistoricalEnergyRecordDraft],
        context: ModelContext
    ) throws -> [String: HistoricalEnergyRecord] {
        guard let start = drafts.map(\.intervalStart).min() else { return [:] }
        let end = drafts.map(\.intervalEnd).max() ?? start
        let descriptor = FetchDescriptor<HistoricalEnergyRecord>(
            predicate: #Predicate<HistoricalEnergyRecord> { record in
                record.intervalStart >= start && record.intervalStart < end
            }
        )
        let existing = try context.fetch(descriptor)
        var map: [String: HistoricalEnergyRecord] = [:]
        map.reserveCapacity(existing.count)
        for record in existing {
            map[record.deduplicationKey] = record
        }
        return map
    }

    nonisolated private static func rebuildDailySummaries(
        dayKeys: Set<String>,
        updatedAt: Date,
        context: ModelContext,
        calendar: Calendar
    ) throws {
        for dayKey in dayKeys {
            let records = try fetchRecords(dayKey: dayKey, context: context)
            let groupedRecords = Dictionary(grouping: records) { record in
                SummaryGroupKey(priceArea: record.priceArea, providerID: record.providerID)
            }

            for (groupKey, groupRecords) in groupedRecords {
                guard let firstRecord = groupRecords.first else { continue }
                let summaryKey = EnergyHistoryKey.summaryKey(
                    periodKey: dayKey,
                    priceArea: groupKey.priceArea,
                    providerID: groupKey.providerID
                )
                let stats = makeSummaryStats(from: groupRecords)
                let dayStart = calendar.startOfDay(for: firstRecord.intervalStart)

                if let existingSummary = try fetchDailySummary(summaryKey: summaryKey, context: context) {
                    existingSummary.update(
                        providerID: groupKey.providerID,
                        date: dayStart,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    )
                } else {
                    context.insert(HistoricalDailyEnergySummary(
                        summaryKey: summaryKey,
                        dayKey: dayKey,
                        monthKey: firstRecord.monthKey,
                        date: dayStart,
                        priceArea: groupKey.priceArea,
                        providerID: groupKey.providerID,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    ))
                }
            }
        }
    }

    nonisolated private static func rebuildMonthlySummaries(
        monthKeys: Set<String>,
        updatedAt: Date,
        context: ModelContext,
        calendar: Calendar
    ) throws {
        for monthKey in monthKeys {
            let dailies = try fetchDailySummaryModels(monthKey: monthKey, context: context)
            let grouped = Dictionary(grouping: dailies) { summary in
                SummaryGroupKey(priceArea: summary.priceArea, providerID: summary.providerID)
            }

            for (groupKey, groupDays) in grouped {
                guard let first = groupDays.first else { continue }
                let summaryKey = EnergyHistoryKey.summaryKey(
                    periodKey: monthKey,
                    priceArea: groupKey.priceArea,
                    providerID: groupKey.providerID
                )
                let stats = makeSummaryStats(fromDaily: groupDays)
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: first.date)) ?? first.date

                if let existingSummary = try fetchMonthlySummary(summaryKey: summaryKey, context: context) {
                    existingSummary.update(
                        providerID: groupKey.providerID,
                        monthStart: monthStart,
                        dayCount: groupDays.count,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    )
                } else {
                    context.insert(HistoricalMonthlyEnergySummary(
                        summaryKey: summaryKey,
                        monthKey: monthKey,
                        monthStart: monthStart,
                        priceArea: groupKey.priceArea,
                        providerID: groupKey.providerID,
                        dayCount: groupDays.count,
                        intervalCount: stats.intervalCount,
                        measuredIntervalCount: stats.measuredIntervalCount,
                        totalConsumptionKWh: stats.totalConsumptionKWh,
                        totalCostSEK: stats.totalCostSEK,
                        averageSpotPriceOrePerKWh: stats.averageSpotPriceOrePerKWh,
                        minSpotPriceOrePerKWh: stats.minSpotPriceOrePerKWh,
                        maxSpotPriceOrePerKWh: stats.maxSpotPriceOrePerKWh,
                        confidence: stats.confidence,
                        updatedAt: updatedAt
                    ))
                }
            }
        }
    }

    nonisolated private static func writeCSV(_ text: String, to stream: OutputStream) throws {
        var bytes = Array(text.utf8)
        var written = 0
        while written < bytes.count {
            let result = bytes.withUnsafeMutableBytes { raw -> Int in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                return stream.write(base + written, maxLength: bytes.count - written)
            }
            if result < 0 {
                throw stream.streamError ?? EnergyHistoryStoreError.exportFailed("csv")
            }
            written += result
        }
    }

    nonisolated private static func upsertSnapshotRecord(
        snapshotHash: String,
        data: Data,
        context: ModelContext
    ) throws {
        let hash = snapshotHash
        var descriptor = FetchDescriptor<HistoricalCostProfileSnapshotRecord>(
            predicate: #Predicate<HistoricalCostProfileSnapshotRecord> { record in
                record.snapshotHash == hash
            }
        )
        descriptor.fetchLimit = 1
        if try context.fetch(descriptor).first != nil {
            return
        }
        context.insert(
            HistoricalCostProfileSnapshotRecord(snapshotHash: hash, snapshotData: data)
        )
    }

    nonisolated private static func costProfile(
        for record: HistoricalEnergyRecord,
        context: ModelContext
    ) throws -> CostProfile? {
        if let hash = record.snapshotHash {
            var descriptor = FetchDescriptor<HistoricalCostProfileSnapshotRecord>(
                predicate: #Predicate<HistoricalCostProfileSnapshotRecord> { snapshot in
                    snapshot.snapshotHash == hash
                }
            )
            descriptor.fetchLimit = 1
            if let stored = try context.fetch(descriptor).first,
               let snapshot = try? JSONDecoder().decode(HistoricalCostProfileSnapshot.self, from: stored.snapshotData) {
                return CostProfile(historySnapshot: snapshot)
            }
        }
        if let data = record.costProfileSnapshotData,
           let snapshot = try? JSONDecoder().decode(HistoricalCostProfileSnapshot.self, from: data) {
            return CostProfile(historySnapshot: snapshot)
        }
        return nil
    }

    nonisolated private static func fetchRecords(
        monthKey: String?,
        priceArea: String?,
        context: ModelContext
    ) throws -> [HistoricalEnergyRecord] {
        let descriptor: FetchDescriptor<HistoricalEnergyRecord>
        if let monthKey, let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.monthKey == monthKey && record.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        } else if let monthKey {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.monthKey == monthKey
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        } else if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalEnergyRecord> { record in
                    record.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        } else {
            descriptor = FetchDescriptor(
                sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
            )
        }
        return try context.fetch(descriptor)
    }

    nonisolated private static func csvNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        return AppFormatters.csvNumber(value)
    }

    nonisolated private static func csvNumber(_ value: Double) -> String {
        AppFormatters.csvNumber(value)
    }

    nonisolated private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    nonisolated private static func fetchRecords(dayKey: String, context: ModelContext) throws -> [HistoricalEnergyRecord] {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalEnergyRecord> { record in
                record.dayKey == dayKey
            },
            sortBy: [SortDescriptor(\HistoricalEnergyRecord.intervalStart)]
        )
        return try context.fetch(descriptor)
    }

    nonisolated private static func fetchDailySummaryModels(monthKey: String, context: ModelContext) throws -> [HistoricalDailyEnergySummary] {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalDailyEnergySummary> { summary in
                summary.monthKey == monthKey
            }
        )
        return try context.fetch(descriptor)
    }

    nonisolated private static func fetchDailySummary(summaryKey: String, context: ModelContext) throws -> HistoricalDailyEnergySummary? {
        var descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalDailyEnergySummary> { summary in
                summary.summaryKey == summaryKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated private static func fetchMonthlySummary(summaryKey: String, context: ModelContext) throws -> HistoricalMonthlyEnergySummary? {
        var descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                summary.summaryKey == summaryKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated private static func updateWidgetSummaryCache(monthKeys: Set<String>, updatedAt: Date, context: ModelContext) throws {
        for monthKey in monthKeys {
            let summaries = try fetchMonthlySummaries(monthKey: monthKey, priceArea: nil, context: context)
            let groupedByPriceArea = Dictionary(grouping: summaries, by: \.priceArea)
            for (_, priceAreaSummaries) in groupedByPriceArea {
                guard let summary = priceAreaSummaries.max(by: { lhs, rhs in rhs.isPreferred(over: lhs) }) else {
                    continue
                }
                WidgetHistorySummaryCache.store(WidgetHistorySummary(summary: summary, updatedAt: updatedAt))
            }
        }
    }

    nonisolated private static func rebuildWidgetSummaryCache(context: ModelContext) throws {
        let descriptor = FetchDescriptor<HistoricalMonthlyEnergySummary>(
            sortBy: [SortDescriptor(\HistoricalMonthlyEnergySummary.monthStart, order: .reverse)]
        )
        let summaries = try context.fetch(descriptor).map { $0.summaryValue() }
        let grouped = Dictionary(grouping: summaries) { summary in
            SummaryCacheKey(monthKey: summary.periodKey, priceArea: summary.priceArea)
        }
        let widgetSummaries = grouped.compactMap { _, group in
            group.max { lhs, rhs in rhs.isPreferred(over: lhs) }.map { WidgetHistorySummary(summary: $0) }
        }
        WidgetHistorySummaryCache.replaceAll(widgetSummaries)
    }

    nonisolated private static func deleteRecords(before cutoff: Date, context: ModelContext) throws {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalEnergyRecord> { record in
                record.intervalStart < cutoff
            }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
    }

    nonisolated private static func deleteDailySummaries(before cutoff: Date, context: ModelContext) throws {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalDailyEnergySummary> { summary in
                summary.date < cutoff
            }
        )
        for summary in try context.fetch(descriptor) {
            context.delete(summary)
        }
    }

    nonisolated private static func deleteMonthlySummaries(before cutoff: Date, context: ModelContext) throws {
        let descriptor = FetchDescriptor(
            predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                summary.monthStart < cutoff
            }
        )
        for summary in try context.fetch(descriptor) {
            context.delete(summary)
        }
    }

    nonisolated private static func deleteAll<T: PersistentModel>(_ modelType: T.Type, context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<T>()) {
            context.delete(record)
        }
    }

    nonisolated private static func makeSummaryStats(from records: [HistoricalEnergyRecord]) -> SummaryStats {
        let intervalCount = records.count
        let measuredRecords = records.filter { $0.consumptionKWh != nil }
        let totalConsumption = measuredRecords.reduce(0) { $0 + ($1.consumptionKWh ?? 0) }
        let totalCosts = records.compactMap(\.totalCostSEK)
        let spotPrices = records.map(\.spotPriceOrePerKWh)

        return SummaryStats(
            intervalCount: intervalCount,
            measuredIntervalCount: measuredRecords.count,
            totalConsumptionKWh: measuredRecords.isEmpty ? nil : totalConsumption,
            totalCostSEK: totalCosts.isEmpty ? nil : totalCosts.reduce(0, +),
            averageSpotPriceOrePerKWh: spotPrices.isEmpty ? nil : spotPrices.reduce(0, +) / Double(spotPrices.count),
            minSpotPriceOrePerKWh: spotPrices.min(),
            maxSpotPriceOrePerKWh: spotPrices.max(),
            confidence: summaryConfidence(for: records.map(\.confidence))
        )
    }

    nonisolated private static func makeSummaryStats(fromDaily dailies: [HistoricalDailyEnergySummary]) -> SummaryStats {
        let intervalCount = dailies.reduce(0) { $0 + $1.intervalCount }
        let measuredIntervalCount = dailies.reduce(0) { $0 + $1.measuredIntervalCount }
        let consumptions = dailies.compactMap(\.totalConsumptionKWh)
        let costs = dailies.compactMap(\.totalCostSEK)
        let weightedSpot = dailies.reduce(0.0) { partial, day in
            partial + (day.averageSpotPriceOrePerKWh ?? 0) * Double(max(day.intervalCount, 1))
        }
        let weight = dailies.reduce(0) { $0 + max($1.intervalCount, 1) }

        return SummaryStats(
            intervalCount: intervalCount,
            measuredIntervalCount: measuredIntervalCount,
            totalConsumptionKWh: consumptions.isEmpty ? nil : consumptions.reduce(0, +),
            totalCostSEK: costs.isEmpty ? nil : costs.reduce(0, +),
            averageSpotPriceOrePerKWh: dailies.isEmpty ? nil : weightedSpot / Double(max(weight, 1)),
            minSpotPriceOrePerKWh: dailies.compactMap(\.minSpotPriceOrePerKWh).min(),
            maxSpotPriceOrePerKWh: dailies.compactMap(\.maxSpotPriceOrePerKWh).max(),
            confidence: summaryConfidence(for: dailies.map(\.confidence))
        )
    }

    nonisolated private static func summaryConfidence(for confidences: [HistoricalEnergyConfidence]) -> HistoricalEnergyConfidence {
        guard !confidences.isEmpty else { return .priceOnly }
        let unique = Set(confidences)
        if unique == [.measured] {
            return .measured
        }
        if unique.contains(.measured) || unique.contains(.partial) {
            return .partial
        }
        if unique.contains(.recalculated) {
            return .recalculated
        }
        if unique.contains(.estimated) {
            return .estimated
        }
        return .priceOnly
    }
}

nonisolated private struct SummaryGroupKey: Hashable, Sendable {
    let priceArea: String
    let providerID: String?
}

nonisolated private struct SummaryCacheKey: Hashable, Sendable {
    let monthKey: String
    let priceArea: String
}

nonisolated private struct SummaryStats: Sendable {
    let intervalCount: Int
    let measuredIntervalCount: Int
    let totalConsumptionKWh: Double?
    let totalCostSEK: Double?
    let averageSpotPriceOrePerKWh: Double?
    let minSpotPriceOrePerKWh: Double?
    let maxSpotPriceOrePerKWh: Double?
    let confidence: HistoricalEnergyConfidence
}
