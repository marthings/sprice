//
//  EnergyHistoryStore.swift
//  Spotprice
//
//  Local SwiftData persistence for historical electricity records.
//

import Foundation
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
    func fetchTopCostDays(monthKey: String, priceArea: String?, limit: Int) throws -> [HistoricalEnergySummaryValue]
    func fetchTopConsumptionDays(monthKey: String, priceArea: String?, limit: Int) throws -> [HistoricalEnergySummaryValue]
    func exportHistoryCSV(priceArea: String?) throws -> String
    func pruneHistory(keepingRecentMonths monthCount: Int) throws
    func deleteAllHistory() throws
}

// MARK: - Errors

enum EnergyHistoryStoreError: LocalizedError {
    case missingAppGroupContainer(String)

    var errorDescription: String? {
        switch self {
        case .missingAppGroupContainer(let identifier):
            return "App Group container saknas för \(identifier). Kontrollera target-entitlements."
        }
    }
}

// MARK: - SwiftData Model Container

enum EnergyHistoryModelContainer {
    enum CurrentSchema: VersionedSchema {
        static let versionIdentifier = Schema.Version(1, 0, 0)

        static var models: [any PersistentModel.Type] {
            [
                HistoricalEnergyRecord.self,
                HistoricalDailyEnergySummary.self,
                HistoricalMonthlyEnergySummary.self
            ]
        }
    }

    static func makeLocalContainer() throws -> ModelContainer {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: EnergyHistoryConstants.appGroupIdentifier) != nil else {
            throw EnergyHistoryStoreError.missingAppGroupContainer(EnergyHistoryConstants.appGroupIdentifier)
        }

        let schema = Schema(CurrentSchema.models, version: CurrentSchema.versionIdentifier)

        let configuration = ModelConfiguration(
            EnergyHistoryConstants.storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(EnergyHistoryConstants.appGroupIdentifier),
            // Keep local-only until sync has explicit UI, entitlements, migration, and conflict handling.
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(CurrentSchema.models, version: CurrentSchema.versionIdentifier)

        let configuration = ModelConfiguration(
            EnergyHistoryConstants.storeName,
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
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
        try self.init(container: EnergyHistoryModelContainer.makeLocalContainer())
    }

    func upsertRecords(_ drafts: [HistoricalEnergyRecordDraft]) throws {
        guard !drafts.isEmpty else { return }

        let now = Date()
        var affectedDayKeys = Set<String>()
        var affectedMonthKeys = Set<String>()

        for draft in drafts {
            affectedDayKeys.insert(draft.dayKey)
            affectedMonthKeys.insert(draft.monthKey)

            if let existingRecord = try fetchRecord(deduplicationKey: draft.deduplicationKey) {
                existingRecord.update(from: draft, updatedAt: now)
            } else {
                context.insert(draft.makeRecord(createdAt: now))
            }
        }

        try rebuildDailySummaries(dayKeys: affectedDayKeys, updatedAt: now)
        try rebuildMonthlySummaries(monthKeys: affectedMonthKeys, updatedAt: now)
        try context.save()
        try updateWidgetSummaryCache(monthKeys: affectedMonthKeys, updatedAt: now)
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
        let descriptor: FetchDescriptor<HistoricalMonthlyEnergySummary>

        if let priceArea {
            descriptor = FetchDescriptor(
                predicate: #Predicate<HistoricalMonthlyEnergySummary> { summary in
                    summary.priceArea == priceArea
                },
                sortBy: [SortDescriptor(\HistoricalMonthlyEnergySummary.monthStart)]
            )
        } else {
            descriptor = FetchDescriptor(
                sortBy: [SortDescriptor(\HistoricalMonthlyEnergySummary.monthStart)]
            )
        }

        return try context.fetch(descriptor).map { $0.summaryValue() }
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
        return value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...6)))
    }

    private func csvNumber(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...6)))
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
        summaries.sorted { lhs, rhs in
            let lhsRank = widgetSummaryRank(lhs)
            let rhsRank = widgetSummaryRank(rhs)
            if lhsRank == rhsRank {
                return lhs.intervalCount > rhs.intervalCount
            }
            return lhsRank > rhsRank
        }.first
    }

    private func widgetSummaryRank(_ summary: HistoricalEnergySummaryValue) -> Int {
        switch summary.dataCoverage {
        case .measuredConsumption:
            return 4
        case .partialConsumption:
            return 3
        case .estimatedCost:
            return 2
        case .priceOnly:
            return 1
        }
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
        Dictionary(grouping: summaries, by: \.periodKey)
            .compactMap { _, summaries in
                summaries.sorted { lhs, rhs in
                    let lhsRank = summaryDataCoverageRank(lhs)
                    let rhsRank = summaryDataCoverageRank(rhs)
                    if lhsRank == rhsRank {
                        return lhs.intervalCount > rhs.intervalCount
                    }
                    return lhsRank > rhsRank
                }
                .first
            }
    }

    private func summaryDataCoverageRank(_ summary: HistoricalEnergySummaryValue) -> Int {
        switch summary.dataCoverage {
        case .measuredConsumption:
            return 4
        case .partialConsumption:
            return 3
        case .estimatedCost:
            return 2
        case .priceOnly:
            return 1
        }
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

private struct SummaryGroupKey: Hashable {
    let priceArea: String
    let providerID: String?
}

private struct SummaryCacheKey: Hashable {
    let monthKey: String
    let priceArea: String
}

private struct SummaryStats {
    let intervalCount: Int
    let measuredIntervalCount: Int
    let totalConsumptionKWh: Double?
    let totalCostSEK: Double?
    let averageSpotPriceOrePerKWh: Double?
    let minSpotPriceOrePerKWh: Double?
    let maxSpotPriceOrePerKWh: Double?
    let confidence: HistoricalEnergyConfidence
}
