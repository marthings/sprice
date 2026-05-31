//
//  EnergyHistoryRecorder.swift
//  Spotprice
//
//  Converts loaded price and energy data into local history records.
//

import Foundation

// MARK: - Energy History Recorder

@MainActor
final class EnergyHistoryRecorder {
    private struct ConsumptionInterval {
        let start: Date
        let end: Date
        let kWh: Double
        let hoursInPeriod: Double
    }

    private let store: EnergyHistoryStore
    private let calendar: Calendar
    private let totalCostService: TotalCostService

    init(
        store: EnergyHistoryStore,
        totalCostService: TotalCostService? = nil,
        calendar: Calendar? = nil
    ) {
        self.store = store
        self.totalCostService = totalCostService ?? TotalCostService()
        self.calendar = calendar ?? .energyHistory
    }

    convenience init() throws {
        try self.init(store: SwiftDataEnergyHistoryStore())
    }

    func recordPriceHistory(dayData: DayChartData, priceArea: String) {
        let drafts = dayData.buckets.map { bucket in
            HistoricalEnergyRecordDraft(
                intervalStart: bucket.start,
                intervalEnd: bucket.end,
                priceArea: priceArea,
                spotPriceOrePerKWh: bucket.orePerKWh,
                source: .spotPrice,
                confidence: .priceOnly,
                calendar: calendar
            )
        }

        guard !drafts.isEmpty else {
            print("🕘 History: No price buckets to record")
            return
        }

        do {
            try store.upsertRecords(drafts)
            print("🕘 History: Recorded \(drafts.count) price intervals for \(priceArea)")
        } catch {
            print("🕘 History: Failed to record price history - \(error.localizedDescription)")
        }
    }

    func recordCurrentMonthConsumptionHistory(
        consumptionService: ConsumptionService,
        spotPriceService: SpotPriceService,
        priceArea: String,
        providerID: String,
        costProfile: CostProfile,
        now: Date = Date()
    ) async {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            print("🕘 History: Could not calculate current month start")
            return
        }

        do {
            let intervals = try await fetchConsumptionIntervals(
                consumptionService: consumptionService,
                startDate: monthStart,
                endDate: now
            )

            guard !intervals.isEmpty else {
                print("🕘 History: No consumption intervals to record")
                return
            }

            let spotPriceLookup = try await fetchSpotPriceLookup(
                for: intervals,
                spotPriceService: spotPriceService,
                priceArea: priceArea
            )
            let snapshot = HistoricalCostProfileSnapshot(profile: costProfile, capturedAt: now)

            let matchedIntervals = intervals.compactMap { interval -> (interval: ConsumptionInterval, spotPriceOre: Double)? in
                guard let spotPriceOre = matchingSpotPrice(for: interval.start, in: spotPriceLookup) else {
                    return nil
                }
                return (interval, spotPriceOre)
            }
            let confidence: HistoricalEnergyConfidence = matchedIntervals.count == intervals.count ? .measured : .partial
            let drafts = matchedIntervals.map { matched in
                let cost = totalCostService.calculateTotalCost(
                    kWh: matched.interval.kWh,
                    spotPriceOre: matched.spotPriceOre,
                    profile: costProfile,
                    hoursInPeriod: matched.interval.hoursInPeriod
                )

                return HistoricalEnergyRecordDraft(
                    intervalStart: matched.interval.start,
                    intervalEnd: matched.interval.end,
                    priceArea: priceArea,
                    providerID: providerID,
                    spotPriceOrePerKWh: matched.spotPriceOre,
                    consumptionKWh: matched.interval.kWh,
                    energyCostSEK: cost.providerTotalKr,
                    gridCostSEK: cost.gridTotalKr,
                    taxCostSEK: cost.taxesAndFeesKr,
                    vatCostSEK: nil,
                    totalCostSEK: cost.totalKr,
                    costProfileSnapshot: snapshot,
                    source: .measuredConsumption,
                    confidence: confidence,
                    calendar: calendar
                )
            }

            guard !drafts.isEmpty else {
                print("🕘 History: Consumption had no matching spot prices")
                return
            }

            try store.upsertRecords(drafts)
            print("🕘 History: Recorded \(drafts.count)/\(intervals.count) consumption cost intervals for \(priceArea) via \(providerID)")
        } catch {
            print("🕘 History: Failed to record consumption history - \(error.localizedDescription)")
        }
    }

    private func fetchConsumptionIntervals(
        consumptionService: ConsumptionService,
        startDate: Date,
        endDate: Date
    ) async throws -> [ConsumptionInterval] {
        do {
            let quarterly = try await consumptionService.fetchQuarterlyConsumption(startDate: startDate, endDate: endDate)
            if !quarterly.isEmpty {
                return quarterly.map { entry in
                    ConsumptionInterval(
                        start: entry.date,
                        end: calendar.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date.addingTimeInterval(15 * 60),
                        kWh: entry.kWh,
                        hoursInPeriod: 0.25
                    )
                }
            }
        } catch {
            print("🕘 History: Quarterly consumption unavailable, trying hourly - \(error.localizedDescription)")
        }

        let hourly = try await consumptionService.fetchHourlyConsumption(startDate: startDate, endDate: endDate)
        return hourly.map { entry in
            ConsumptionInterval(
                start: entry.date,
                end: calendar.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(60 * 60),
                kWh: entry.kWh,
                hoursInPeriod: 1.0
            )
        }
    }

    private func fetchSpotPriceLookup(
        for intervals: [ConsumptionInterval],
        spotPriceService: SpotPriceService,
        priceArea: String
    ) async throws -> [Date: Double] {
        let days = Set(intervals.map { calendar.startOfDay(for: $0.start) })
        var lookup: [Date: Double] = [:]

        for day in days.sorted() {
            do {
                let items = try await spotPriceService.fetchSpotPrices(for: day, area: priceArea)
                for item in items {
                    lookup[item.timeStart] = item.sekPerKWh * 100.0
                }
            } catch {
                print("🕘 History: Failed to fetch spot prices for \(day) - \(error.localizedDescription)")
            }
        }

        return lookup
    }

    private func matchingSpotPrice(for date: Date, in lookup: [Date: Double]) -> Double? {
        guard let hourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: date)) else {
            return nil
        }
        return lookup[hourStart]
    }
}
