import SwiftUI
import Charts

struct MonthDailyCostSection: View {
    let priceArea: String
    let profile: CostProfile
    let hasProvider: Bool

    @State private var days: [MonthDayCost] = []
    @State private var selectedDay: MonthDayCost?
    @State private var loadFailed = false
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Kostnad per dag")
                    .font(DS.Font.headline)

                Text("Så här har månaden kostat hittills. Tryck på en stapel för att se den dagen.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !didLoad {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if loadFailed || days.allSatisfy({ $0.costKr == nil }) {
                emptyMessage(emptyStateCopy)
            } else {
                chartContent
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task(id: priceArea) {
            await loadDays()
        }
        .onChange(of: hasProvider) { _, _ in
            Task { await loadDays() }
        }
        .onAppear {
            guard didLoad else { return }
            Task { await loadDays() }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if let expensive = mostExpensiveDay, let cost = expensive.costKr {
            Text("Dyrast: \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kr")
                .font(DS.Font.semibold(12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Dyraste dagen är \(AppFormatters.weekdayDayMonth(expensive.date)), \(AppFormatters.wholeNumber(cost)) kronor")
        }

        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Dag", day.date, unit: .day),
                    y: .value("kr", day.costKr ?? 0)
                )
                .foregroundStyle(barColor(for: day))
                .cornerRadius(3)
                .opacity(barOpacity(for: day))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                AxisGridLine()
                    .foregroundStyle(.tertiary)
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.day())
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.tertiary)
                AxisTick()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .number.precision(.fractionLength(0)))
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
        .frame(height: 180)
        .overlay {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                selectedDay = nearestDay(at: value.location, chartWidth: geometry.size.width)
                            }
                    )
            }
        }
        .accessibilityLabel("Stapeldiagram över kostnad per dag den här månaden")

        if let selectedDay {
            Text(detailCopy(for: selectedDay))
                .font(DS.Font.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
        }

        Text("Stapeln för idag visar bara det som har hänt hittills.")
            .font(DS.Font.micro)
            .foregroundStyle(DS.Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyStateCopy: String {
        if hasProvider {
            return "Förbrukningen för den här månaden har inte kommit in ännu. När den finns ser du vad varje dag har kostat."
        }
        return "Gå till Inställningar och lägg till förbrukning. Då kan du se vad varje dag har kostat den här månaden."
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(DS.Font.callout)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var mostExpensiveDay: MonthDayCost? {
        days
            .compactMap { day -> (MonthDayCost, Double)? in
                guard let cost = day.costKr, cost > 0 else { return nil }
                return (day, cost)
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    private var xAxisStride: Int {
        switch days.count {
        case ...7: return 1
        case ...14: return 2
        case ...21: return 3
        default: return 5
        }
    }

    private func nearestDay(at location: CGPoint, chartWidth: CGFloat) -> MonthDayCost? {
        guard !days.isEmpty, chartWidth > 0 else { return nil }
        let dayIndex = Int((location.x / chartWidth) * Double(days.count))
        let clampedIndex = max(0, min(dayIndex, days.count - 1))
        return days[clampedIndex]
    }

    private func barColor(for day: MonthDayCost) -> Color {
        if day.id == mostExpensiveDay?.id {
            return DS.Color.danger
        }
        return DS.Color.info
    }

    private func barOpacity(for day: MonthDayCost) -> Double {
        if day.costKr == nil {
            return 0.18
        }
        if selectedDay == nil || selectedDay?.id == day.id {
            return 1
        }
        return 0.35
    }

    private func detailCopy(for day: MonthDayCost) -> String {
        let heading = AppFormatters.weekdayDayMonth(day.date)
        if let cost = day.costKr {
            let kWhText: String
            if let kWh = day.kWh {
                kWhText = " · \(AppFormatters.kWh(kWh, fractionLength: 0...1))"
            } else {
                kWhText = ""
            }
            if day.isToday {
                return "Idag så långt: \(AppFormatters.wholeNumber(cost)) kr\(kWhText). Dagen är inte slut."
            }
            return "\(heading): \(AppFormatters.wholeNumber(cost)) kr\(kWhText)"
        }
        if day.isToday {
            return "Idag så långt finns ingen förbrukning sparad ännu."
        }
        return "\(heading): ingen förbrukning sparad för den här dagen."
    }

    @MainActor
    private func loadDays() async {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthKey = EnergyHistoryKey.monthKey(for: now, calendar: calendar)

        do {
            let history = try EnergyHistoryQueryService().loadMonthHistory(
                priceArea: priceArea,
                selectedMonthKey: monthKey
            )
            days = MonthDailyCostBuilder.bars(
                from: history.dailySummaries,
                profile: profile,
                now: now,
                calendar: calendar
            )
            loadFailed = false
        } catch {
            days = []
            loadFailed = true
        }
        didLoad = true
    }
}

struct MonthDayCost: Identifiable, Equatable {
    let date: Date
    let costKr: Double?
    let kWh: Double?
    let isToday: Bool

    var id: Date { date }
}

enum MonthDailyCostBuilder {
    static func bars(
        from summaries: [HistoricalEnergySummaryValue],
        profile: CostProfile,
        now: Date,
        calendar: Calendar
    ) -> [MonthDayCost] {
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return []
        }
        return bars(
            from: summaries,
            profile: profile,
            monthStart: monthStart,
            lastDay: now,
            now: now,
            calendar: calendar
        )
    }

    static func bars(
        from summaries: [HistoricalEnergySummaryValue],
        profile: CostProfile,
        monthStart: Date,
        lastDay: Date,
        now: Date,
        calendar: Calendar
    ) -> [MonthDayCost] {
        let summariesByDay = Dictionary(
            summaries.map { (EnergyHistoryKey.dayKey(for: $0.periodStart, calendar: calendar), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let service = TotalCostService()
        var bars: [MonthDayCost] = []
        var dayStart = monthStart
        let lastDayStart = calendar.startOfDay(for: lastDay)

        while dayStart <= lastDayStart {
            let key = EnergyHistoryKey.dayKey(for: dayStart, calendar: calendar)
            let isToday = calendar.isDate(dayStart, inSameDayAs: now)
            let summary = summariesByDay[key]
            let hoursInPeriod = isToday
                ? max(now.timeIntervalSince(calendar.startOfDay(for: now)) / 3600, 1 / 60)
                : 24
            let kWh = summary?.totalConsumptionKWh
            let cost = dayCostKr(
                summary: summary,
                kWh: kWh,
                hoursInPeriod: hoursInPeriod,
                profile: profile,
                service: service
            )

            bars.append(MonthDayCost(date: dayStart, costKr: cost, kWh: kWh, isToday: isToday))
            guard let next = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = next
        }

        return bars
    }

    private static func dayCostKr(
        summary: HistoricalEnergySummaryValue?,
        kWh: Double?,
        hoursInPeriod: Double,
        profile: CostProfile,
        service: TotalCostService
    ) -> Double? {
        if let kWh, kWh > 0, let spot = summary?.averageSpotPriceOrePerKWh {
            return service.calculateTotalCost(
                kWh: kWh,
                spotPriceOre: spot,
                profile: profile,
                hoursInPeriod: hoursInPeriod
            ).totalKr
        }
        return summary?.totalCostSEK
    }
}
