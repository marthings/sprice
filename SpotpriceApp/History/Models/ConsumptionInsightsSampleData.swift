#if DEBUG
import Foundation

enum ConsumptionInsightsSampleData {
    static let priceArea = "SE3"

    static func octoberMonthRoute() -> ConsumptionInsightsRoute {
        ConsumptionInsightsRoute(
            period: .month(
                monthKey: EnergyHistoryKey.monthKey(for: monthStart),
                previousMonthKey: EnergyHistoryKey.monthKey(for: previousMonthStart),
                periodStart: monthStart
            ),
            priceArea: priceArea
        )
    }

    static func fridayRoute() -> ConsumptionInsightsRoute {
        ConsumptionInsightsRoute(
            period: .day(dayKey: EnergyHistoryKey.dayKey(for: friday), date: friday),
            priceArea: priceArea
        )
    }

    static func monthInsights(includeEffectTariff: Bool = true) -> ConsumptionInsights {
        _ = ConsumptionInsightsBuilder.debugVerifyAlgorithms()
        return ConsumptionInsightsBuilder.make(
            intervals: monthIntervals(),
            previousIntervals: previousMonthNightIntervals(),
            dailySummaries: [],
            costProfile: costProfile(includeEffectTariff: includeEffectTariff),
            periodStart: monthStart,
            periodEnd: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            now: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            periodKind: .month
        )
    }

    static func dayInsights() -> ConsumptionInsights {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: friday)!
        return ConsumptionInsightsBuilder.make(
            intervals: intervals(forDay: friday, includeOven: true, includeCharge: false),
            previousIntervals: [],
            dailySummaries: [],
            costProfile: costProfile(includeEffectTariff: true),
            periodStart: friday,
            periodEnd: dayEnd,
            now: dayEnd,
            periodKind: .day
        )
    }

    static func dailyOnlyInsights() -> ConsumptionInsights {
        ConsumptionInsightsBuilder.make(
            intervals: [],
            previousIntervals: [],
            dailySummaries: dailySummaries(),
            costProfile: costProfile(includeEffectTariff: false),
            periodStart: monthStart,
            periodEnd: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            now: calendar.date(byAdding: .month, value: 1, to: monthStart)!,
            periodKind: .month
        )
    }

    private static var calendar: Calendar { .energyHistory }

    private static var monthStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
    }

    private static var previousMonthStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
    }

    private static var friday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16))!
    }

    private static var saturday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 17))!
    }

    private static func costProfile(includeEffectTariff: Bool) -> CostProfile {
        let tariff = includeEffectTariff
            ? EffectTariff(monthlyPricePerKW: 50, model: .singlePeak, activeHours: .allHours)
            : nil
        return CostProfile.swedishDefaultEstimate().settingEffectTariff(tariff)
    }

    private static func monthIntervals() -> [HistoricalEnergyIntervalValue] {
        var result: [HistoricalEnergyIntervalValue] = []
        for dayOffset in 0..<31 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) else {
                continue
            }
            let isFriday = calendar.isDate(day, inSameDayAs: friday)
            let isSaturday = calendar.isDate(day, inSameDayAs: saturday)
            result.append(contentsOf: intervals(forDay: day, includeOven: isFriday, includeCharge: isSaturday))
        }
        return result
    }

    private static func previousMonthNightIntervals() -> [HistoricalEnergyIntervalValue] {
        (0..<5).flatMap { dayOffset -> [HistoricalEnergyIntervalValue] in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: previousMonthStart) else {
                return []
            }
            return (0..<20).map { index in
                interval(
                    start: day.addingTimeInterval(Double(index) * 900),
                    kWh: 0.10,
                    spotOre: 25
                )
            }
        }
    }

    private static func intervals(
        forDay day: Date,
        includeOven: Bool,
        includeCharge: Bool
    ) -> [HistoricalEnergyIntervalValue] {
        (0..<96).map { index in
            let start = day.addingTimeInterval(Double(index) * 900)
            let hour = calendar.component(.hour, from: start)
            let kWh: Double
            if hour < 5 {
                kWh = 0.08
            } else if includeCharge && hour >= 10 && hour < 14 {
                kWh = 0.60
            } else if includeOven && hour == 17 {
                kWh = 2.0
            } else if hour >= 7 && hour < 9 {
                kWh = 0.28
            } else if hour >= 17 && hour < 22 {
                kWh = 0.12
            } else {
                kWh = 0.12
            }
            let spot: Double
            if hour < 6 {
                spot = 22
            } else if hour >= 17 {
                spot = 155
            } else {
                spot = 70
            }
            return interval(start: start, kWh: kWh, spotOre: spot)
        }
    }

    private static func interval(start: Date, kWh: Double, spotOre: Double) -> HistoricalEnergyIntervalValue {
        let priceKr = (spotOre / 100) + 0.80
        return HistoricalEnergyIntervalValue(
            id: UUID(),
            intervalStart: start,
            intervalEnd: start.addingTimeInterval(900),
            spotPriceOrePerKWh: spotOre,
            consumptionKWh: kWh,
            energyCostSEK: nil,
            gridCostSEK: nil,
            taxCostSEK: nil,
            vatCostSEK: nil,
            totalCostSEK: kWh * priceKr
        )
    }

    private static func dailySummaries() -> [HistoricalEnergySummaryValue] {
        (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
            let kWh = 28.0 + Double(dayOffset % 5) * 3
            return HistoricalEnergySummaryValue(
                id: UUID(),
                periodKey: EnergyHistoryKey.dayKey(for: date),
                periodStart: date,
                priceArea: priceArea,
                providerID: "tibber",
                intervalCount: 24,
                measuredIntervalCount: 24,
                totalConsumptionKWh: kWh,
                totalCostSEK: kWh * 1.6,
                averageSpotPriceOrePerKWh: 70,
                minSpotPriceOrePerKWh: 20,
                maxSpotPriceOrePerKWh: 160,
                confidence: .measured
            )
        }
    }
}
#endif
