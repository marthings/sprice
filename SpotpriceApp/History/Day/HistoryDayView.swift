import SwiftUI
import Charts

struct HistoryDayView: View {
    let date: Date
    let dayKey: String
    let dailySummary: HistoricalEnergySummaryValue?
    let costProfile: CostProfile
    let priceArea: String

    private let historyQuery: any EnergyHistoryQuerying
    private let previewSnapshot: HistoryDaySnapshot?

    @State private var snapshot: HistoryDaySnapshot?
    @State private var loadFailed = false

    init(
        date: Date,
        dayKey: String,
        dailySummary: HistoricalEnergySummaryValue?,
        costProfile: CostProfile,
        priceArea: String,
        historyQuery: (any EnergyHistoryQuerying)? = nil,
        previewSnapshot: HistoryDaySnapshot? = nil
    ) {
        self.date = date
        self.dayKey = dayKey
        self.dailySummary = dailySummary
        self.costProfile = costProfile
        self.priceArea = priceArea
        self.historyQuery = historyQuery ?? EnergyHistoryQueryService()
        self.previewSnapshot = previewSnapshot
        _snapshot = State(initialValue: previewSnapshot)
    }

    var body: some View {
        ZStack {
            AppCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let snapshot {
                        HistoryDayTotals(snapshot: snapshot)
                        HistoryDayHourChart(snapshot: snapshot)
                        if snapshot.hasMeasuredUse {
                            HistoryDayExpensiveHours(hours: snapshot.expensiveHoursUsed)
                        }
                        if let split = snapshot.split, split.hasValues {
                            HistoryDayCostSplitView(split: split)
                        }
                    } else if loadFailed {
                        AppStatusCard(
                            icon: "clock.badge",
                            title: "Ingen timhistorik att visa",
                            message: "Det finns inga sparade intervall för den här dagen. Historik fylls på när appen har hämtat priser.",
                            color: DS.Color.secondary
                        )
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl * 4)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(AppFormatters.weekdayDayMonth(date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .task {
            guard previewSnapshot == nil else { return }
            await loadDay()
        }
    }

    @MainActor
    private func loadDay() async {
        do {
            let intervals = try historyQuery.loadDayIntervals(dayKey: dayKey, priceArea: priceArea)
            snapshot = HistoryDayInsights.snapshot(
                date: date,
                dailySummary: dailySummary,
                intervals: intervals,
                costProfile: costProfile
            )
            loadFailed = false
        } catch {
            if dailySummary != nil {
                snapshot = HistoryDayInsights.snapshot(
                    date: date,
                    dailySummary: dailySummary,
                    intervals: [],
                    costProfile: costProfile
                )
                loadFailed = false
            } else {
                snapshot = nil
                loadFailed = true
            }
        }
    }
}

private struct HistoryDayTotals: View {
    let snapshot: HistoryDaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                if let cost = snapshot.costKr {
                    dayMetric(value: AppFormatters.wholeNumber(cost), unit: "kr", label: "Kostnad")
                }
                if let kWh = snapshot.kWh {
                    dayMetric(value: AppFormatters.kWhValue(kWh), unit: "kWh", label: "Förbrukning")
                }
                if let paid = snapshot.paidKrPerKWh {
                    dayMetric(
                        value: paid.formatted(.number.precision(.fractionLength(2))),
                        unit: "kr/kWh",
                        label: "Betalt pris"
                    )
                }
            }

            if snapshot.costKr == nil && snapshot.kWh == nil {
                Text("Ingen förbrukning sparad för den här dagen. Kurvan visar bara spotpriset när det finns.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if snapshot.isIncomplete {
                Text("Dagen är inte komplett. Siffrorna visar bara det som har hänt hittills.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func dayMetric(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(DS.Font.bold(28).monospacedDigit())
                Text(unit)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(unit)")
    }
}

private struct HistoryDayHourChart: View {
    let snapshot: HistoryDaySnapshot

    private var hasCost: Bool {
        snapshot.hours.contains { $0.costKr != nil }
    }

    private var hasSpot: Bool {
        snapshot.hours.contains { $0.spotOrePerKWh != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("När pengarna gick")
                .font(DS.Font.headline)

            if hasCost {
                Chart {
                    ForEach(costHours) { hour in
                        BarMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("kr", hour.costKr ?? 0)
                        )
                        .foregroundStyle(costBarColor(for: hour))
                        .cornerRadius(2)
                    }
                }
                .chartXScale(domain: hourDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisGridLine()
                            .foregroundStyle(.tertiary)
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
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
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .number.precision(.fractionLength(0)))
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Stapeldiagram över kostnad per timme, i kronor")
            } else {
                Text("Ingen kostnad per timme att visa. Förbrukning saknas, så inga kronor räknas fram.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasSpot {
                Text("Spotpris, öre/kWh")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)

                Chart {
                    ForEach(spotHours) { hour in
                        LineMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("öre/kWh", hour.spotOrePerKWh ?? 0)
                        )
                        .foregroundStyle(DS.Color.warning)
                        .interpolationMethod(.stepStart)
                        AreaMark(
                            x: .value("Timme", hour.start, unit: .hour),
                            y: .value("öre/kWh", hour.spotOrePerKWh ?? 0)
                        )
                        .foregroundStyle(DS.Color.warning.opacity(0.12))
                        .interpolationMethod(.stepStart)
                    }
                }
                .chartXScale(domain: hourDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisGridLine()
                            .foregroundStyle(.tertiary)
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
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
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .number.precision(.fractionLength(0)))
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
                .frame(height: 96)
                .accessibilityLabel("Linjediagram över spotpris per timme, i öre per kilowattimme")
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var costHours: [HistoryHourCost] {
        snapshot.hours.filter { $0.costKr != nil }
    }

    private var spotHours: [HistoryHourCost] {
        snapshot.hours.filter { $0.spotOrePerKWh != nil }
    }

    private var hourDomain: ClosedRange<Date> {
        let start = snapshot.hours.first?.start ?? snapshot.date
        let last = snapshot.hours.last?.start ?? start
        return start...last.addingTimeInterval(3600)
    }

    private func costBarColor(for hour: HistoryHourCost) -> Color {
        if snapshot.expensiveHoursUsed.contains(where: { $0.id == hour.id }) {
            return DS.Color.danger
        }
        return DS.Color.info
    }
}

private struct HistoryDayExpensiveHours: View {
    let hours: [HistoryHourCost]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Du drog el när det var dyrt")
                .font(DS.Font.headline)

            Text("Inte börsens dyraste timme, utan de timmar du faktiskt använde när det kostade mest.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if hours.isEmpty {
                Text("Det finns ingen mätt förbrukning att peka ut timmar från.")
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(hours) { hour in
                    HStack {
                        Text(hour.hourRangeLabel)
                            .font(DS.Font.callout)
                            .frame(width: 56, alignment: .leading)
                        Spacer(minLength: DS.Spacing.sm)
                        if let cost = hour.costKr {
                            Text("\(AppFormatters.wholeNumber(cost)) kr")
                                .font(DS.Font.semibold(16).monospacedDigit())
                        }
                        if let kWh = hour.kWh {
                            Text(AppFormatters.kWh(kWh, fractionLength: 0...1))
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.secondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(for: hour))
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func accessibilityLabel(for hour: HistoryHourCost) -> String {
        var parts = ["Klockan \(hour.hourRangeLabel)"]
        if let cost = hour.costKr {
            parts.append("\(AppFormatters.wholeNumber(cost)) kronor")
        }
        if let kWh = hour.kWh {
            parts.append(AppFormatters.kWh(kWh, fractionLength: 0...1))
        }
        return parts.joined(separator: ", ")
    }
}

private struct HistoryDayCostSplitView: View {
    let split: HistoryDayCostSplit

    private var rows: [(title: String, amount: Double)] {
        [
            ("Elhandel", split.energyKr),
            ("Nät", split.gridKr),
            ("Skatt", split.taxKr),
            ("Moms", split.vatKr)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Så fördelades kostnaden")
                .font(DS.Font.headline)

            GeometryReader { geometry in
                let total = max(split.totalKr, 0.0001)
                HStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        Rectangle()
                            .fill(color(for: index))
                            .frame(width: geometry.size.width * CGFloat(max(row.amount, 0) / total))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(color(for: index))
                        .frame(width: 8, height: 8)
                    Text(row.title)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(AppFormatters.kr(row.amount, fractionLength: 2))
                        .font(DS.Font.micro.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.title) \(AppFormatters.kr(row.amount, fractionLength: 2))")
            }

            Text("Siffrorna i listan är utan moms. Momsen ligger på en egen rad. Totalen är vad du betalar.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if split.usedCurrentTariffs {
                Text("Äldre rader saknade uppdelning. Det här är räknat med dina nuvarande tariffer.")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func color(for index: Int) -> Color {
        switch index {
        case 0: return DS.Color.info
        case 1: return DS.Color.warning
        case 2: return DS.Color.success
        default: return Color.gray
        }
    }
}
