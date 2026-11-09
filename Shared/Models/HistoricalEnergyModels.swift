//
//  HistoricalEnergyModels.swift
//  Spotprice
//
//  SwiftData models and value types for local electricity history.
//

import Foundation
import SwiftData

// MARK: - Historical Energy Constants

nonisolated enum EnergyHistoryConstants {
    static let appGroupIdentifier = "group.mb.Spotprice"
    static let storeName = "EnergyHistory"
}

// MARK: - Historical Energy Source

nonisolated enum HistoricalEnergySource: String, Codable, CaseIterable, Sendable {
    case spotPrice
    case estimatedCost
    case measuredConsumption
    case imported
    case recalculated
}

// MARK: - Historical Energy Confidence

nonisolated enum HistoricalEnergyConfidence: String, Codable, CaseIterable, Equatable, Sendable {
    case priceOnly
    case estimated
    case measured
    case partial
    case recalculated
}

// MARK: - Historical Cost Profile Snapshot

nonisolated struct HistoricalCostProfileSnapshot: Codable, Equatable, Sendable {
    let priceArea: String
    let retailContractType: String
    let retailerMarkupOrePerKWh: Double
    let contractPriceOrePerKWh: Double?
    let retailerMonthlyFee: Double
    let retailContractSource: String?
    let gridCompanyId: String?
    let gridCompanyName: String?
    let fuseSize: Int?
    let gridMonthlyFee: Double?
    let gridTransferOrePerKWh: Double?
    let gridCostSource: String?
    let energyTaxOrePerKWh: Double
    let certificateFeeOrePerKWh: Double
    let vatRate: Double
    let confidence: String
    let source: String
    let tariffLastUpdated: Date?
    let tariffValidUntil: Date?
    let capturedAt: Date

    init(profile: CostProfile, capturedAt: Date = Date()) {
        self.priceArea = profile.priceArea
        self.retailContractType = profile.retailContractType.rawValue
        self.retailerMarkupOrePerKWh = profile.retailerMarkupOrePerKWh
        self.contractPriceOrePerKWh = profile.contractPriceOrePerKWh
        self.retailerMonthlyFee = profile.retailerMonthlyFee
        self.retailContractSource = profile.retailContractSource?.rawValue
        self.gridCompanyId = profile.gridCompanyId
        self.gridCompanyName = profile.gridCompanyName
        self.fuseSize = profile.fuseSize
        self.gridMonthlyFee = profile.gridMonthlyFee
        self.gridTransferOrePerKWh = profile.gridTransferOrePerKWh
        self.gridCostSource = profile.gridCostSource?.rawValue
        self.energyTaxOrePerKWh = profile.energyTaxOrePerKWh
        self.certificateFeeOrePerKWh = profile.certificateFeeOrePerKWh
        self.vatRate = profile.vatRate
        self.confidence = profile.confidence.rawValue
        self.source = profile.source.rawValue
        self.tariffLastUpdated = profile.tariffLastUpdated
        self.tariffValidUntil = profile.tariffValidUntil
        self.capturedAt = capturedAt
    }
}

// MARK: - Historical Energy Record

@Model
final class HistoricalEnergyRecord {
    #Unique<HistoricalEnergyRecord>([\.deduplicationKey])
    #Index<HistoricalEnergyRecord>([\.deduplicationKey], [\.dayKey, \.priceArea], [\.monthKey, \.priceArea], [\.intervalStart])

    var id: UUID
    var deduplicationKey: String
    var intervalStart: Date
    var intervalEnd: Date
    var dayKey: String
    var monthKey: String
    var priceArea: String
    var providerID: String?

    var spotPriceOrePerKWh: Double
    var consumptionKWh: Double?

    var energyCostSEK: Double?
    var gridCostSEK: Double?
    var taxCostSEK: Double?
    var vatCostSEK: Double?
    var totalCostSEK: Double?

    @Attribute(.externalStorage)
    var costProfileSnapshotData: Data?

    var sourceRawValue: String
    var confidenceRawValue: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        deduplicationKey: String,
        intervalStart: Date,
        intervalEnd: Date,
        dayKey: String,
        monthKey: String,
        priceArea: String,
        providerID: String?,
        spotPriceOrePerKWh: Double,
        consumptionKWh: Double?,
        energyCostSEK: Double?,
        gridCostSEK: Double?,
        taxCostSEK: Double?,
        vatCostSEK: Double?,
        totalCostSEK: Double?,
        costProfileSnapshotData: Data?,
        source: HistoricalEnergySource,
        confidence: HistoricalEnergyConfidence,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.deduplicationKey = deduplicationKey
        self.intervalStart = intervalStart
        self.intervalEnd = intervalEnd
        self.dayKey = dayKey
        self.monthKey = monthKey
        self.priceArea = priceArea
        self.providerID = providerID
        self.spotPriceOrePerKWh = spotPriceOrePerKWh
        self.consumptionKWh = consumptionKWh
        self.energyCostSEK = energyCostSEK
        self.gridCostSEK = gridCostSEK
        self.taxCostSEK = taxCostSEK
        self.vatCostSEK = vatCostSEK
        self.totalCostSEK = totalCostSEK
        self.costProfileSnapshotData = costProfileSnapshotData
        self.sourceRawValue = source.rawValue
        self.confidenceRawValue = confidence.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var source: HistoricalEnergySource {
        HistoricalEnergySource(rawValue: sourceRawValue) ?? .spotPrice
    }

    var confidence: HistoricalEnergyConfidence {
        HistoricalEnergyConfidence(rawValue: confidenceRawValue) ?? .priceOnly
    }

    func update(from draft: HistoricalEnergyRecordDraft, snapshotData: Data? = nil, updatedAt: Date = Date()) {
        intervalStart = draft.intervalStart
        intervalEnd = draft.intervalEnd
        dayKey = draft.dayKey
        monthKey = draft.monthKey
        priceArea = draft.priceArea
        providerID = draft.providerID
        spotPriceOrePerKWh = draft.spotPriceOrePerKWh
        consumptionKWh = draft.consumptionKWh
        energyCostSEK = draft.energyCostSEK
        gridCostSEK = draft.gridCostSEK
        taxCostSEK = draft.taxCostSEK
        vatCostSEK = draft.vatCostSEK
        totalCostSEK = draft.totalCostSEK
        costProfileSnapshotData = snapshotData ?? costProfileSnapshotData
        sourceRawValue = draft.source.rawValue
        confidenceRawValue = draft.confidence.rawValue
        self.updatedAt = updatedAt
    }

    func intervalValue() -> HistoricalEnergyIntervalValue {
        HistoricalEnergyIntervalValue(
            id: id,
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            spotPriceOrePerKWh: spotPriceOrePerKWh,
            consumptionKWh: consumptionKWh,
            energyCostSEK: energyCostSEK,
            gridCostSEK: gridCostSEK,
            taxCostSEK: taxCostSEK,
            vatCostSEK: vatCostSEK,
            totalCostSEK: totalCostSEK
        )
    }
}

struct HistoricalEnergyIntervalValue: Identifiable, Equatable, Sendable {
    let id: UUID
    let intervalStart: Date
    let intervalEnd: Date
    let spotPriceOrePerKWh: Double
    let consumptionKWh: Double?
    let energyCostSEK: Double?
    let gridCostSEK: Double?
    let taxCostSEK: Double?
    let vatCostSEK: Double?
    let totalCostSEK: Double?
}

// MARK: - Historical Energy Summary Models

@Model
final class HistoricalDailyEnergySummary {
    #Unique<HistoricalDailyEnergySummary>([\.summaryKey])
    #Index<HistoricalDailyEnergySummary>([\.summaryKey], [\.monthKey], [\.date], [\.monthKey, \.priceArea])

    var id: UUID
    var summaryKey: String
    var dayKey: String
    var monthKey: String
    var date: Date
    var priceArea: String
    var providerID: String?
    var intervalCount: Int
    var measuredIntervalCount: Int
    var totalConsumptionKWh: Double?
    var totalCostSEK: Double?
    var averageSpotPriceOrePerKWh: Double?
    var minSpotPriceOrePerKWh: Double?
    var maxSpotPriceOrePerKWh: Double?
    var confidenceRawValue: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        summaryKey: String,
        dayKey: String,
        monthKey: String,
        date: Date,
        priceArea: String,
        providerID: String?,
        intervalCount: Int,
        measuredIntervalCount: Int,
        totalConsumptionKWh: Double?,
        totalCostSEK: Double?,
        averageSpotPriceOrePerKWh: Double?,
        minSpotPriceOrePerKWh: Double?,
        maxSpotPriceOrePerKWh: Double?,
        confidence: HistoricalEnergyConfidence,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.summaryKey = summaryKey
        self.dayKey = dayKey
        self.monthKey = monthKey
        self.date = date
        self.priceArea = priceArea
        self.providerID = providerID
        self.intervalCount = intervalCount
        self.measuredIntervalCount = measuredIntervalCount
        self.totalConsumptionKWh = totalConsumptionKWh
        self.totalCostSEK = totalCostSEK
        self.averageSpotPriceOrePerKWh = averageSpotPriceOrePerKWh
        self.minSpotPriceOrePerKWh = minSpotPriceOrePerKWh
        self.maxSpotPriceOrePerKWh = maxSpotPriceOrePerKWh
        self.confidenceRawValue = confidence.rawValue
        self.updatedAt = updatedAt
    }

    var confidence: HistoricalEnergyConfidence {
        HistoricalEnergyConfidence(rawValue: confidenceRawValue) ?? .priceOnly
    }

    func update(
        providerID: String?,
        date: Date,
        intervalCount: Int,
        measuredIntervalCount: Int,
        totalConsumptionKWh: Double?,
        totalCostSEK: Double?,
        averageSpotPriceOrePerKWh: Double?,
        minSpotPriceOrePerKWh: Double?,
        maxSpotPriceOrePerKWh: Double?,
        confidence: HistoricalEnergyConfidence,
        updatedAt: Date = Date()
    ) {
        self.providerID = providerID
        self.date = date
        self.intervalCount = intervalCount
        self.measuredIntervalCount = measuredIntervalCount
        self.totalConsumptionKWh = totalConsumptionKWh
        self.totalCostSEK = totalCostSEK
        self.averageSpotPriceOrePerKWh = averageSpotPriceOrePerKWh
        self.minSpotPriceOrePerKWh = minSpotPriceOrePerKWh
        self.maxSpotPriceOrePerKWh = maxSpotPriceOrePerKWh
        self.confidenceRawValue = confidence.rawValue
        self.updatedAt = updatedAt
    }

    func summaryValue() -> HistoricalEnergySummaryValue {
        HistoricalEnergySummaryValue(
            id: id,
            periodKey: dayKey,
            periodStart: date,
            priceArea: priceArea,
            providerID: providerID,
            intervalCount: intervalCount,
            measuredIntervalCount: measuredIntervalCount,
            totalConsumptionKWh: totalConsumptionKWh,
            totalCostSEK: totalCostSEK,
            averageSpotPriceOrePerKWh: averageSpotPriceOrePerKWh,
            minSpotPriceOrePerKWh: minSpotPriceOrePerKWh,
            maxSpotPriceOrePerKWh: maxSpotPriceOrePerKWh,
            confidence: confidence
        )
    }
}

@Model
final class HistoricalMonthlyEnergySummary {
    #Unique<HistoricalMonthlyEnergySummary>([\.summaryKey])
    #Index<HistoricalMonthlyEnergySummary>([\.summaryKey], [\.monthKey], [\.monthStart])

    var id: UUID
    var summaryKey: String
    var monthKey: String
    var monthStart: Date
    var priceArea: String
    var providerID: String?
    var dayCount: Int
    var intervalCount: Int
    var measuredIntervalCount: Int
    var totalConsumptionKWh: Double?
    var totalCostSEK: Double?
    var averageSpotPriceOrePerKWh: Double?
    var minSpotPriceOrePerKWh: Double?
    var maxSpotPriceOrePerKWh: Double?
    var confidenceRawValue: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        summaryKey: String,
        monthKey: String,
        monthStart: Date,
        priceArea: String,
        providerID: String?,
        dayCount: Int,
        intervalCount: Int,
        measuredIntervalCount: Int,
        totalConsumptionKWh: Double?,
        totalCostSEK: Double?,
        averageSpotPriceOrePerKWh: Double?,
        minSpotPriceOrePerKWh: Double?,
        maxSpotPriceOrePerKWh: Double?,
        confidence: HistoricalEnergyConfidence,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.summaryKey = summaryKey
        self.monthKey = monthKey
        self.monthStart = monthStart
        self.priceArea = priceArea
        self.providerID = providerID
        self.dayCount = dayCount
        self.intervalCount = intervalCount
        self.measuredIntervalCount = measuredIntervalCount
        self.totalConsumptionKWh = totalConsumptionKWh
        self.totalCostSEK = totalCostSEK
        self.averageSpotPriceOrePerKWh = averageSpotPriceOrePerKWh
        self.minSpotPriceOrePerKWh = minSpotPriceOrePerKWh
        self.maxSpotPriceOrePerKWh = maxSpotPriceOrePerKWh
        self.confidenceRawValue = confidence.rawValue
        self.updatedAt = updatedAt
    }

    var confidence: HistoricalEnergyConfidence {
        HistoricalEnergyConfidence(rawValue: confidenceRawValue) ?? .priceOnly
    }

    func update(
        providerID: String?,
        monthStart: Date,
        dayCount: Int,
        intervalCount: Int,
        measuredIntervalCount: Int,
        totalConsumptionKWh: Double?,
        totalCostSEK: Double?,
        averageSpotPriceOrePerKWh: Double?,
        minSpotPriceOrePerKWh: Double?,
        maxSpotPriceOrePerKWh: Double?,
        confidence: HistoricalEnergyConfidence,
        updatedAt: Date = Date()
    ) {
        self.providerID = providerID
        self.monthStart = monthStart
        self.dayCount = dayCount
        self.intervalCount = intervalCount
        self.measuredIntervalCount = measuredIntervalCount
        self.totalConsumptionKWh = totalConsumptionKWh
        self.totalCostSEK = totalCostSEK
        self.averageSpotPriceOrePerKWh = averageSpotPriceOrePerKWh
        self.minSpotPriceOrePerKWh = minSpotPriceOrePerKWh
        self.maxSpotPriceOrePerKWh = maxSpotPriceOrePerKWh
        self.confidenceRawValue = confidence.rawValue
        self.updatedAt = updatedAt
    }

    func summaryValue() -> HistoricalEnergySummaryValue {
        HistoricalEnergySummaryValue(
            id: id,
            periodKey: monthKey,
            periodStart: monthStart,
            priceArea: priceArea,
            providerID: providerID,
            intervalCount: intervalCount,
            measuredIntervalCount: measuredIntervalCount,
            totalConsumptionKWh: totalConsumptionKWh,
            totalCostSEK: totalCostSEK,
            averageSpotPriceOrePerKWh: averageSpotPriceOrePerKWh,
            minSpotPriceOrePerKWh: minSpotPriceOrePerKWh,
            maxSpotPriceOrePerKWh: maxSpotPriceOrePerKWh,
            confidence: confidence
        )
    }
}

// MARK: - Drafts

nonisolated struct HistoricalEnergyRecordDraft: Sendable {
    let deduplicationKey: String
    let intervalStart: Date
    let intervalEnd: Date
    let dayKey: String
    let monthKey: String
    let priceArea: String
    let providerID: String?
    let spotPriceOrePerKWh: Double
    let consumptionKWh: Double?
    let energyCostSEK: Double?
    let gridCostSEK: Double?
    let taxCostSEK: Double?
    let vatCostSEK: Double?
    let totalCostSEK: Double?
    let costProfileSnapshot: HistoricalCostProfileSnapshot?
    let source: HistoricalEnergySource
    let confidence: HistoricalEnergyConfidence

    init(
        intervalStart: Date,
        intervalEnd: Date,
        priceArea: String,
        providerID: String? = nil,
        spotPriceOrePerKWh: Double,
        consumptionKWh: Double? = nil,
        energyCostSEK: Double? = nil,
        gridCostSEK: Double? = nil,
        taxCostSEK: Double? = nil,
        vatCostSEK: Double? = nil,
        totalCostSEK: Double? = nil,
        costProfileSnapshot: HistoricalCostProfileSnapshot? = nil,
        source: HistoricalEnergySource,
        confidence: HistoricalEnergyConfidence,
        calendar: Calendar = .energyHistory
    ) {
        self.intervalStart = intervalStart
        self.intervalEnd = intervalEnd
        self.dayKey = EnergyHistoryKey.dayKey(for: intervalStart, calendar: calendar)
        self.monthKey = EnergyHistoryKey.monthKey(for: intervalStart, calendar: calendar)
        self.priceArea = priceArea
        self.providerID = providerID
        self.spotPriceOrePerKWh = spotPriceOrePerKWh
        self.consumptionKWh = consumptionKWh
        self.energyCostSEK = energyCostSEK
        self.gridCostSEK = gridCostSEK
        self.taxCostSEK = taxCostSEK
        self.vatCostSEK = vatCostSEK
        self.totalCostSEK = totalCostSEK
        self.costProfileSnapshot = costProfileSnapshot
        self.source = source
        self.confidence = confidence
        self.deduplicationKey = EnergyHistoryKey.recordKey(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            priceArea: priceArea,
            providerID: providerID,
            source: source,
            calendar: calendar
        )
    }

    func makeRecord(createdAt: Date = Date(), snapshotData: Data? = nil) -> HistoricalEnergyRecord {
        HistoricalEnergyRecord(
            deduplicationKey: deduplicationKey,
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            dayKey: dayKey,
            monthKey: monthKey,
            priceArea: priceArea,
            providerID: providerID,
            spotPriceOrePerKWh: spotPriceOrePerKWh,
            consumptionKWh: consumptionKWh,
            energyCostSEK: energyCostSEK,
            gridCostSEK: gridCostSEK,
            taxCostSEK: taxCostSEK,
            vatCostSEK: vatCostSEK,
            totalCostSEK: totalCostSEK,
            costProfileSnapshotData: snapshotData,
            source: source,
            confidence: confidence,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

// MARK: - Query Values

struct HistoricalEnergyDateRange: Sendable {
    let start: Date
    let end: Date
}

nonisolated struct HistoricalEnergySummaryValue: Equatable, Identifiable, Sendable {
    let id: UUID
    let periodKey: String
    let periodStart: Date
    let priceArea: String
    let providerID: String?
    let intervalCount: Int
    let measuredIntervalCount: Int
    let totalConsumptionKWh: Double?
    let totalCostSEK: Double?
    let averageSpotPriceOrePerKWh: Double?
    let minSpotPriceOrePerKWh: Double?
    let maxSpotPriceOrePerKWh: Double?
    let confidence: HistoricalEnergyConfidence

    var dataCoverage: HistoricalEnergyDataCoverage {
        if measuredIntervalCount > 0 {
            return measuredIntervalCount < intervalCount ? .partialConsumption : .measuredConsumption
        }
        if totalCostSEK != nil {
            return .estimatedCost
        }
        return .priceOnly
    }

    var measuredCoverageRatio: Double? {
        guard intervalCount > 0, measuredIntervalCount > 0 else { return nil }
        return Double(measuredIntervalCount) / Double(intervalCount)
    }

    var averageTotalCostSEKPerKWh: Double? {
        guard let totalCostSEK,
              let totalConsumptionKWh,
              totalConsumptionKWh > 0 else {
            return nil
        }
        return totalCostSEK / totalConsumptionKWh
    }

    var hasMissingConsumptionIntervals: Bool {
        measuredIntervalCount > 0 && measuredIntervalCount < intervalCount
    }
}

nonisolated enum HistoricalEnergyDataCoverage: String, Codable, CaseIterable, Sendable {
    case priceOnly
    case estimatedCost
    case partialConsumption
    case measuredConsumption

    var qualityRank: Int {
        switch self {
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
}

extension HistoricalEnergySummaryValue {
    func isPreferred(over other: HistoricalEnergySummaryValue) -> Bool {
        let lhsRank = dataCoverage.qualityRank
        let rhsRank = other.dataCoverage.qualityRank

        if lhsRank == rhsRank {
            return intervalCount > other.intervalCount
        }
        return lhsRank > rhsRank
    }
}

extension Sequence where Element == HistoricalEnergySummaryValue {
    func bestSummaries<Key: Hashable>(
        groupedBy keyPath: KeyPath<HistoricalEnergySummaryValue, Key>
    ) -> [HistoricalEnergySummaryValue] {
        Dictionary(grouping: self, by: { $0[keyPath: keyPath] })
            .compactMap { _, summaries in
                summaries.max { lhs, rhs in rhs.isPreferred(over: lhs) }
            }
    }
}

nonisolated struct WidgetHistorySummary: Codable, Equatable, Sendable {
    let monthKey: String
    let priceArea: String
    let periodStart: Date
    let totalConsumptionKWh: Double?
    let totalCostSEK: Double?
    let averageSpotPriceOrePerKWh: Double?
    let dataCoverage: HistoricalEnergyDataCoverage
    let measuredCoverageRatio: Double?
    let updatedAt: Date

    init(summary: HistoricalEnergySummaryValue, updatedAt: Date = Date()) {
        self.monthKey = summary.periodKey
        self.priceArea = summary.priceArea
        self.periodStart = summary.periodStart
        self.totalConsumptionKWh = summary.totalConsumptionKWh
        self.totalCostSEK = summary.totalCostSEK
        self.averageSpotPriceOrePerKWh = summary.averageSpotPriceOrePerKWh
        self.dataCoverage = summary.dataCoverage
        self.measuredCoverageRatio = summary.measuredCoverageRatio
        self.updatedAt = updatedAt
    }

    func isCurrentMonth(at date: Date = Date(), calendar: Calendar = .energyHistory) -> Bool {
        monthKey == EnergyHistoryKey.monthKey(for: date, calendar: calendar)
    }
}

nonisolated enum WidgetHistorySummaryCache: Sendable {
    private static let defaults = UserDefaults(suiteName: EnergyHistoryConstants.appGroupIdentifier) ?? .standard
    private static let key = "widget_historySummaries"

    nonisolated static func summary(monthKey: String, priceArea: String) -> WidgetHistorySummary? {
        summaries().first { summary in
            summary.monthKey == monthKey && summary.priceArea == priceArea
        }
    }

    nonisolated static func store(_ summary: WidgetHistorySummary) {
        var cached = summaries().filter { existing in
            !(existing.monthKey == summary.monthKey && existing.priceArea == summary.priceArea)
        }
        cached.append(summary)
        cached.sort { $0.periodStart > $1.periodStart }
        cached = Array(cached.prefix(12))

        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: key)
            defaults.synchronize()
        }
    }

    nonisolated static func replaceAll(_ summaries: [WidgetHistorySummary]) {
        let cached = Array(summaries.sorted { $0.periodStart > $1.periodStart }.prefix(12))
        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }

    nonisolated static func clear() {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }

    nonisolated private static func summaries() -> [WidgetHistorySummary] {
        guard let data = defaults.data(forKey: key),
              let summaries = try? JSONDecoder().decode([WidgetHistorySummary].self, from: data) else {
            return []
        }
        return summaries
    }
}

// MARK: - Keys

nonisolated enum EnergyHistoryKey: Sendable {
    nonisolated static func recordKey(
        intervalStart: Date,
        intervalEnd: Date,
        priceArea: String,
        providerID: String?,
        source: HistoricalEnergySource,
        calendar: Calendar = .energyHistory
    ) -> String {
        [
            instantKey(for: intervalStart, calendar: calendar),
            instantKey(for: intervalEnd, calendar: calendar),
            priceArea,
            providerID ?? "none",
            source.rawValue
        ].joined(separator: "|")
    }

    nonisolated static func summaryKey(periodKey: String, priceArea: String, providerID: String?) -> String {
        [periodKey, priceArea, providerID ?? "none"].joined(separator: "|")
    }

    nonisolated static func dayKey(for date: Date, calendar: Calendar = .energyHistory) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(paddedYear(components.year ?? 0))-\(paddedTwo(components.month ?? 0))-\(paddedTwo(components.day ?? 0))"
    }

    nonisolated static func monthKey(for date: Date, calendar: Calendar = .energyHistory) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(paddedYear(components.year ?? 0))-\(paddedTwo(components.month ?? 0))"
    }

    nonisolated static func preferredMonthKey(
        from months: [HistoricalEnergySummaryValue],
        now: Date = Date(),
        calendar: Calendar = .energyHistory
    ) -> String? {
        let currentKey = monthKey(for: now, calendar: calendar)
        return months.first { $0.periodKey != currentKey }?.periodKey ?? months.first?.periodKey
    }

    nonisolated private static func instantKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return "\(paddedYear(components.year ?? 0))-\(paddedTwo(components.month ?? 0))-\(paddedTwo(components.day ?? 0))T\(paddedTwo(components.hour ?? 0)):\(paddedTwo(components.minute ?? 0))"
    }

    nonisolated private static func paddedTwo(_ value: Int) -> String {
        value < 10 ? "0\(value)" : String(value)
    }

    nonisolated private static func paddedYear(_ value: Int) -> String {
        if value < 0 { return String(value) }
        if value < 10 { return "000\(value)" }
        if value < 100 { return "00\(value)" }
        if value < 1000 { return "0\(value)" }
        return String(value)
    }
}

extension Calendar {
    nonisolated static let energyHistory = AppFormatters.energyCalendar
}
