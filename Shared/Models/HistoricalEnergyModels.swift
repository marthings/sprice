//
//  HistoricalEnergyModels.swift
//  Spotprice
//
//  SwiftData models and value types for local electricity history.
//

import CryptoKit
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
    /// Measured, but the value or its cost may still change (see `HistoryPreliminary`).
    /// Saved in the same string as the other cases, so no schema change.
    case preliminary
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

    nonisolated static func encodedData(_ snapshot: HistoricalCostProfileSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }

    nonisolated static func hash(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
    var snapshotHash: String?

    var sourceRawValue: String
    var confidenceRawValue: String
    var createdAt: Date
    /// When the row was last written from fetched data. Repricing leaves it alone, so for a
    /// measured row it tells when the value was fetched (used by `HistoryPreliminary`).
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
        snapshotHash: String? = nil,
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
        self.snapshotHash = snapshotHash
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

    func update(
        from draft: HistoricalEnergyRecordDraft,
        snapshotData: Data? = nil,
        snapshotHash: String? = nil,
        updatedAt: Date = Date()
    ) {
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
        if let snapshotHash {
            self.snapshotHash = snapshotHash
            costProfileSnapshotData = nil
        } else if let snapshotData {
            costProfileSnapshotData = snapshotData
        }
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

@Model
final class HistoricalCostProfileSnapshotRecord {
    #Unique<HistoricalCostProfileSnapshotRecord>([\.snapshotHash])
    #Index<HistoricalCostProfileSnapshotRecord>([\.snapshotHash])

    var snapshotHash: String
    var snapshotData: Data
    var createdAt: Date

    init(snapshotHash: String, snapshotData: Data, createdAt: Date = Date()) {
        self.snapshotHash = snapshotHash
        self.snapshotData = snapshotData
        self.createdAt = createdAt
    }
}

nonisolated struct HistoricalEnergyIntervalValue: Identifiable, Equatable, Sendable {
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

    func makeRecord(
        createdAt: Date = Date(),
        snapshotData: Data? = nil,
        snapshotHash: String? = nil
    ) -> HistoricalEnergyRecord {
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
            costProfileSnapshotData: snapshotHash == nil ? snapshotData : nil,
            snapshotHash: snapshotHash,
            source: source,
            confidence: confidence,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

// MARK: - Query Values

nonisolated struct HistoricalEnergyDateRange: Sendable {
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

    /// Some value or cost in the period may still change.
    var isPreliminary: Bool {
        confidence == .preliminary
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
    nonisolated func isPreferred(over other: HistoricalEnergySummaryValue) -> Bool {
        let lhsRank = dataCoverage.qualityRank
        let rhsRank = other.dataCoverage.qualityRank

        if lhsRank == rhsRank {
            return intervalCount > other.intervalCount
        }
        return lhsRank > rhsRank
    }
}

extension Sequence where Element == HistoricalEnergySummaryValue {
    nonisolated func bestSummaries<Key: Hashable>(
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
    /// Optional so a summary cached before this field still decodes.
    let isPreliminary: Bool?
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
        self.isPreliminary = summary.isPreliminary
        self.updatedAt = updatedAt
    }

    func isCurrentMonth(at date: Date = Date(), calendar: Calendar = .energyHistory) -> Bool {
        monthKey == EnergyHistoryKey.monthKey(for: date, calendar: calendar)
    }
}

nonisolated enum WidgetHistorySummaryCache: Sendable {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: EnergyHistoryConstants.appGroupIdentifier) ?? .standard
    }
    private static let key = "widget_historySummaries"

    nonisolated static func summary(monthKey: String, priceArea: String) -> WidgetHistorySummary? {
        summaries().first { summary in
            summary.monthKey == monthKey && summary.priceArea == priceArea
        }
    }

    nonisolated static func store(_ summary: WidgetHistorySummary) {
        // Demo mode never writes what widgets read.
        guard !DemoMode.isActive else { return }
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
        guard !DemoMode.isActive else { return }
        let cached = Array(summaries.sorted { $0.periodStart > $1.periodStart }.prefix(12))
        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }

    nonisolated static func clear() {
        guard !DemoMode.isActive else { return }
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

// MARK: - Interval coverage

/// Finds hourly consumption that quarter-hours already cover. Quarters win: an hour whose
/// four quarters are all saved (same price area and source) must not be counted again.
nonisolated enum IntervalCoverage {
    struct Item: Sendable {
        let start: Date
        let end: Date
        /// Price area and provider. Only the same group can cover an hour.
        let group: String
    }

    /// Indices of the hours (exactly 60 minutes) whose four quarters are all present.
    /// Nothing else is ever returned: not quarters, not days, not hours with a quarter missing.
    static func coveredHourIndices(_ items: [Item]) -> [Int] {
        var quarters = Set<String>()
        for item in items where item.end.timeIntervalSince(item.start) == 15 * 60 {
            quarters.insert("\(item.group)|\(item.start.timeIntervalSinceReferenceDate)")
        }
        guard !quarters.isEmpty else { return [] }
        return items.indices.filter { index in
            let item = items[index]
            guard item.end.timeIntervalSince(item.start) == 60 * 60 else { return false }
            return (0..<4).allSatisfy { quarter in
                let start = item.start.addingTimeInterval(Double(quarter) * 15 * 60)
                return quarters.contains("\(item.group)|\(start.timeIntervalSinceReferenceDate)")
            }
        }
    }
}

// MARK: - Clock change

/// Times without a UTC offset ("2025-10-26T02:15:00") are ambiguous in the hour the clocks
/// go back: it happens twice. A date parser gives the same instant both times.
nonisolated enum ClockChangeTimes {
    /// When the same instant comes twice and the other reading of that wall-clock time
    /// exists, the second one is moved to it, in the order the values came. Nothing else changes.
    static func resolvingRepeatedHour(_ dates: [Date], calendar: Calendar = .energyHistory) -> [Date] {
        var seen = Set<Date>()
        var result: [Date] = []
        result.reserveCapacity(dates.count)
        for date in dates {
            guard seen.contains(date) else {
                seen.insert(date)
                result.append(date)
                continue
            }
            let candidates = [date.addingTimeInterval(3600), date.addingTimeInterval(-3600)]
            let wallClock = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            if let other = candidates.first(where: { candidate in
                !seen.contains(candidate)
                    && calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate) == wallClock
            }) {
                seen.insert(other)
                result.append(other)
            } else {
                result.append(date)
            }
        }
        return result
    }

    /// True for instants in the second pass of the repeated hour (standard time again,
    /// while the same wall-clock time an hour earlier was summer time).
    static func isSecondPass(_ date: Date, calendar: Calendar) -> Bool {
        let zone = calendar.timeZone
        return !zone.isDaylightSavingTime(for: date) && zone.isDaylightSavingTime(for: date.addingTimeInterval(-3600))
    }
}

#if DEBUG
/// Checks coverage and clock-change rules once in DEBUG builds.
nonisolated enum IntervalCoverageGuard {
    static let isValid: Bool = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        var ok = true
        func check(_ condition: Bool, _ message: String) {
            assert(condition, "IntervalCoverage: \(message)")
            ok = ok && condition
        }
        let hour = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 1)) ?? .distantPast
        func quarter(_ n: Int, _ group: String = "SE3|vaggeryd") -> IntervalCoverage.Item {
            let start = hour.addingTimeInterval(Double(n) * 900)
            return IntervalCoverage.Item(start: start, end: start.addingTimeInterval(900), group: group)
        }
        let hourly = IntervalCoverage.Item(start: hour, end: hour.addingTimeInterval(3600), group: "SE3|vaggeryd")
        let full = [quarter(0), quarter(1), quarter(2), quarter(3), hourly]
        check(IntervalCoverage.coveredHourIndices(full) == [4], "four quarters cover the hour")
        check(IntervalCoverage.coveredHourIndices([quarter(0), quarter(1), quarter(3), hourly]).isEmpty, "a missing quarter keeps the hour")
        check(IntervalCoverage.coveredHourIndices([quarter(0, "SE4|x"), quarter(1, "SE4|x"), quarter(2, "SE4|x"), quarter(3, "SE4|x"), hourly]).isEmpty, "other source keeps the hour")
        check(IntervalCoverage.coveredHourIndices([hourly]).isEmpty, "hour alone stays")
        let day = IntervalCoverage.Item(start: hour, end: hour.addingTimeInterval(86_400), group: "SE3|vaggeryd")
        check(IntervalCoverage.coveredHourIndices(full.dropLast() + [day]).isEmpty, "never a day")

        // 2025-10-26: 02:00 local happens at 00:00 and 01:00 UTC.
        let first = Date(timeIntervalSince1970: 1_761_436_800) // 2025-10-26 00:00 UTC, 02:00 summer time
        let second = first.addingTimeInterval(3600) // 01:00 UTC, 02:00 standard time
        check(calendar.component(.hour, from: first) == 2 && calendar.component(.hour, from: second) == 2, "repeated hour")
        check(ClockChangeTimes.resolvingRepeatedHour([first, second], calendar: calendar) == [first, second], "distinct instants unchanged")
        check(ClockChangeTimes.resolvingRepeatedHour([second, second], calendar: calendar) == [second, first], "parsed twice: other reading")
        check(ClockChangeTimes.resolvingRepeatedHour([hour, hour], calendar: calendar) == [hour, hour], "ordinary hour is not moved")
        check(!ClockChangeTimes.isSecondPass(first, calendar: calendar) && ClockChangeTimes.isSecondPass(second, calendar: calendar), "second pass")
        let firstKey = EnergyHistoryKey.recordKey(intervalStart: first, intervalEnd: first.addingTimeInterval(900), priceArea: "SE3", providerID: "p", source: .measuredConsumption, calendar: calendar)
        let secondKey = EnergyHistoryKey.recordKey(intervalStart: second, intervalEnd: second.addingTimeInterval(900), priceArea: "SE3", providerID: "p", source: .measuredConsumption, calendar: calendar)
        check(firstKey != secondKey, "both passes get their own key")
        check(firstKey.hasPrefix("2025-10-26T02:00|2025-10-26T02:15|"), "summer pass keeps the old key")
        // Spring 2026-03-29 has 23 hours: 02:00 does not exist, keys are unchanged.
        let spring = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 3)) ?? .distantPast
        check(EnergyHistoryKey.recordKey(intervalStart: spring, intervalEnd: spring.addingTimeInterval(900), priceArea: "SE3", providerID: "p", source: .measuredConsumption, calendar: calendar).hasPrefix("2026-03-29T03:00|2026-03-29T03:15|"), "spring keys")
        return ok
    }()
}
#endif

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
        let key = "\(paddedYear(components.year ?? 0))-\(paddedTwo(components.month ?? 0))-\(paddedTwo(components.day ?? 0))T\(paddedTwo(components.hour ?? 0)):\(paddedTwo(components.minute ?? 0))"
        // The hour the clocks go back happens twice. The second pass gets a suffix so both
        // are kept; every other key stays as before, so saved rows still match.
        return ClockChangeTimes.isSecondPass(date, calendar: calendar) ? key + "+std" : key
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

/// Aligns an in-progress month with the same days of the previous month.
nonisolated enum SameDayMonthComparison: Sendable {
    /// Inclusive day-of-month cap, or `nil` when both months are complete (full vs full).
    nonisolated static func throughDay(
        currentMonthStart: Date,
        lastMeasuredInCurrent: Date?,
        previousMonthStart: Date,
        now: Date,
        calendar: Calendar = .energyHistory
    ) -> Int? {
        guard calendar.isDate(currentMonthStart, equalTo: now, toGranularity: .month) else {
            return nil
        }
        guard let lastMeasuredInCurrent,
              calendar.isDate(lastMeasuredInCurrent, equalTo: currentMonthStart, toGranularity: .month) else {
            return nil
        }
        let measuredDay = calendar.component(.day, from: lastMeasuredInCurrent)
        let previousDays = calendar.range(of: .day, in: .month, for: previousMonthStart)?.count ?? measuredDay
        return max(min(measuredDay, previousDays), 1)
    }

    nonisolated static func lastMeasuredDay(
        monthStart: Date,
        dailySummaries: [HistoricalEnergySummaryValue],
        extraDates: [Date] = [],
        calendar: Calendar = .energyHistory
    ) -> Date? {
        let fromDays = dailySummaries.compactMap { summary -> Date? in
            guard calendar.isDate(summary.periodStart, equalTo: monthStart, toGranularity: .month),
                  (summary.totalConsumptionKWh ?? 0) > 0 else {
                return nil
            }
            return summary.periodStart
        }
        let fromExtra = extraDates.filter { calendar.isDate($0, equalTo: monthStart, toGranularity: .month) }
        return (fromDays + fromExtra).max()
    }

    nonisolated static func lastMeasuredDay(
        fromIntervals intervals: [HistoricalEnergyIntervalValue]
    ) -> Date? {
        intervals.compactMap { interval -> Date? in
            guard (interval.consumptionKWh ?? 0) > 0 else { return nil }
            return interval.intervalStart
        }.max()
    }

    nonisolated static func date(_ date: Date, isOnOrBeforeDay throughDay: Int, calendar: Calendar) -> Bool {
        calendar.component(.day, from: date) <= throughDay
    }

    nonisolated static func swedishMonthName(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: Locale(identifier: "sv_SE"), calendar: .energyHistory).month(.wide))
    }

    nonisolated static func rangeLabel(throughDay: Int, monthStart: Date) -> String {
        "1–\(throughDay) \(swedishMonthName(monthStart))"
    }

    /// "oktober" when the dates cover that month, otherwise "1–9 oktober".
    nonisolated static func previousPeriodLabel(from dates: [Date], calendar: Calendar = .energyHistory) -> String? {
        guard let first = dates.min() else { return nil }
        let monthStart = calendar.dateInterval(of: .month, for: first)?.start ?? first
        let maxDay = dates.map { calendar.component(.day, from: $0) }.max() ?? 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? maxDay
        if maxDay < daysInMonth {
            return rangeLabel(throughDay: maxDay, monthStart: monthStart)
        }
        return swedishMonthName(monthStart)
    }

    nonisolated static func restrictingPreviousIntervals(
        _ previous: [HistoricalEnergyIntervalValue],
        lastMeasuredInCurrent: Date?,
        currentMonthStart: Date,
        now: Date,
        calendar: Calendar = .energyHistory
    ) -> [HistoricalEnergyIntervalValue] {
        guard let earliest = previous.map(\.intervalStart).min() else { return previous }
        let previousMonthStart = calendar.dateInterval(of: .month, for: earliest)?.start ?? earliest
        guard let throughDay = throughDay(
            currentMonthStart: currentMonthStart,
            lastMeasuredInCurrent: lastMeasuredInCurrent,
            previousMonthStart: previousMonthStart,
            now: now,
            calendar: calendar
        ) else {
            return previous
        }
        return previous.filter { date($0.intervalStart, isOnOrBeforeDay: throughDay, calendar: calendar) }
    }
}

extension Calendar {
    nonisolated static let energyHistory = AppFormatters.energyCalendar
}
