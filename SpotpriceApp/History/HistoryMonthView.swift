import SwiftUI
import Charts

struct HistoryMonthView: View {
    @State private var state: LoadState = .loading
    @State private var selectedMonthKey: String?
    @State private var viewMode: ViewMode = .chart
    @State private var selectedDay: HistoricalEnergySummaryValue?

    private let priceArea: String?
    private let calendar: Calendar
    private let historyQuery: any EnergyHistoryQuerying
    
    // Preview support - allow injecting initial state
    private let initialState: LoadState?

    // Live data for the current month so that the headline numbers (Kostnad + Förbrukning for the open month)
    // are computed *identically* to the Förbrukning tab (same precise matching + current CostProfile).
    var liveMonthlyConsumption: ConsumptionData? = nil
    var livePreciseCost: PreciseMonthlyCost? = nil

    init(
        priceArea: String? = nil,
        calendar: Calendar = .energyHistory,
        historyQuery: (any EnergyHistoryQuerying)? = nil,
        previewState: LoadState? = nil,
        liveMonthlyConsumption: ConsumptionData? = nil,
        livePreciseCost: PreciseMonthlyCost? = nil
    ) {
        self.priceArea = priceArea
        self.calendar = calendar
        self.historyQuery = historyQuery ?? EnergyHistoryQueryService()
        self.initialState = previewState
        self.liveMonthlyConsumption = liveMonthlyConsumption
        self.livePreciseCost = livePreciseCost
    }
    
    // MARK: - State Types
    
    enum LoadState {
        case loading
        case loaded(HistoryData)
        case failed(String)
    }

    enum ViewMode {
        case chart
        case table
    }

    struct HistoryData {
        let months: [HistoricalEnergySummaryValue]
        let selectedMonth: HistoricalEnergySummaryValue?
        let dailySummaries: [HistoricalEnergySummaryValue]
        let topCostDays: [HistoricalEnergySummaryValue]
        let topConsumptionDays: [HistoricalEnergySummaryValue]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            switch state {
            case .loading:
                DashboardLoadingView()
            case .failed(let message):
                AppStatusCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Kunde inte läsa historik",
                    message: message,
                    color: DS.Color.warning
                )
            case .loaded(let data):
                content(data)
            }
        }
        .task {
            // Only load if we're not in preview mode
            if initialState == nil {
                await loadHistory()
            } else {
                state = initialState!
            }
        }
    }

    @ViewBuilder
    private func content(_ data: HistoryData) -> some View {
        if data.months.isEmpty {
            AppStatusCard(
                icon: "clock.badge",
                title: "Ingen sparad historik än",
                message: "Historik fylls på automatiskt efter lyckade prisuppdateringar. Förbrukning och kostnad visas när sådan data finns sparad.",
                color: DS.Color.secondary
            )
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                monthPicker(data.months)

                if let selectedMonth = data.selectedMonth {
                    let isCurrent = isCurrentMonth(selectedMonth)
                    HistoryMonthSummaryCards(
                        summary: selectedMonth,
                        isCurrentMonth: isCurrent,
                        liveMonthlyConsumption: liveMonthlyConsumption,
                        livePreciseCost: livePreciseCost
                    )

                    HistoryTopDaysSection(
                        title: "Dyraste dagar",
                        emptyMessage: "Kostnadsdagar visas när historiken innehåller beräknad kostnad.",
                        days: data.topCostDays,
                        isCurrentMonth: isCurrent,
                        value: { summary in
                            if isCurrent, 
                               let kWh = summary.totalConsumptionKWh, 
                               kWh > 0, 
                               let spot = summary.averageSpotPriceOrePerKWh {
                                let profile = ConsumptionSettings.shared.costProfile
                                let service = TotalCostService()
                                let c = service.calculateTotalCost(kWh: kWh, spotPriceOre: spot, profile: profile, hoursInPeriod: 24)
                                let cost = c.totalKr
                                return (AppFormatters.wholeNumber(cost), "kr")
                            }
                            return summary.totalCostSEK.map { (AppFormatters.wholeNumber($0), "kr") }
                        }
                    )

                    HistoryTopDaysSection(
                        title: "Högst förbrukning",
                        emptyMessage: "Förbrukningsdagar visas när en datakälla har levererat mätvärden.",
                        days: data.topConsumptionDays,
                        isCurrentMonth: false,
                        value: { summary in
                            summary.totalConsumptionKWh.map { (AppFormatters.kWhValue($0), "kWh") }
                        }
                    )
                }

                HistoryDailyList(
                    days: data.dailySummaries,
                    viewMode: $viewMode,
                    selectedDay: $selectedDay
                )
            }
        }
    }

    private func monthPicker(_ months: [HistoricalEnergySummaryValue]) -> some View {
        Picker("Månad", selection: Binding(
            get: { selectedMonthKey ?? months.first?.periodKey ?? "" },
            set: { selectedMonthKey = $0 }
        )) {
            ForEach(months) { month in
                Text(monthLabel(month.periodStart))
                    .tag(month.periodKey)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isCurrentMonth(_ summary: HistoricalEnergySummaryValue) -> Bool {
        let calendar = Calendar.energyHistory
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let summaryMonth = calendar.component(.month, from: summary.periodStart)
        let summaryYear = calendar.component(.year, from: summary.periodStart)
        return summaryYear == currentYear && summaryMonth == currentMonth
    }

    @MainActor
    private func loadHistory() async {
        do {
            let activePriceArea = priceArea ?? ConsumptionSettings.shared.priceArea
            let history = try historyQuery.loadMonthHistory(
                priceArea: activePriceArea,
                selectedMonthKey: selectedMonthKey
            )

            selectedMonthKey = history.selectedMonthKey
            state = .loaded(HistoryData(
                months: history.months,
                selectedMonth: history.selectedMonth,
                dailySummaries: history.dailySummaries,
                topCostDays: history.topCostDays,
                topConsumptionDays: history.topConsumptionDays
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func monthLabel(_ date: Date) -> String {
        AppFormatters.historyMonthLabel(date)
    }
}

// MARK: - History Summary

private struct HistoryMonthSummaryCards: View {
    let summary: HistoricalEnergySummaryValue
    var isCurrentMonth: Bool = false

    // Live data so we can compute *exactly* the same cost as the Förbrukning tab for the current month.
    var liveMonthlyConsumption: ConsumptionData? = nil
    var livePreciseCost: PreciseMonthlyCost? = nil

    private let totalCostService = TotalCostService()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                let displayedConsumption = liveMonthlyConsumption?.totalKWh ?? summary.totalConsumptionKWh
                let displayedCost = currentMonthCostUsingLiveData ?? (isCurrentMonth ? liveCostForCurrentMonth : summary.totalCostSEK)

                MetricCard(
                    title: isCurrentMonth ? "Kostnad (aktuella tariffer)" : "Kostnad",
                    value: displayedCost.map { AppFormatters.wholeNumber($0) } ?? "-",
                    unit: "kr",
                    icon: "wallet.bifold.fill",
                    color: .primary
                )
                .padding(DS.Spacing.md)
                .glassCard(cornerRadius: DS.Radius.md)
                MetricCard(
                    title: "Förbrukning",
                    value: displayedConsumption.map { AppFormatters.kWhValue($0) } ?? "-",
                    unit: "kWh",
                    icon: "bolt.fill",
                    color: .primary
                )
                .padding(DS.Spacing.md)
                .glassCard(cornerRadius: DS.Radius.md)
            }

            HStack(spacing: DS.Spacing.sm) {
                let averagePriceMetric = averagePriceMetric(summary, liveCost: currentMonthCostUsingLiveData ?? (isCurrentMonth ? liveCostForCurrentMonth : nil))
                MetricCard(
                    title: averagePriceMetric.title,
                    value: averagePriceMetric.value,
                    unit: averagePriceMetric.unit,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .primary
                )
                .padding(DS.Spacing.md)
                .glassCard(cornerRadius: DS.Radius.md)

            }

            if isCurrentMonth {
                Text("Pågående månad. Använder aktuella tariffer och senaste mätdata")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
    }

    /// Computes the month cost using the *exact same logic* as MonthlyConsumptionSection when live data is available.
    /// This guarantees the "Kostnad" number on Historik for the current month is identical to the one on the Förbrukning tab.
    private var currentMonthCostUsingLiveData: Double? {
        guard isCurrentMonth else { return nil }

        let profile = ConsumptionSettings.shared.costProfile
        let consumption = liveMonthlyConsumption
        let preciseCost = livePreciseCost
        let averagePrice = summary.averageSpotPriceOrePerKWh ?? 0   // fallback

        if let consumption {
            if let precise = preciseCost {
                let effectiveSpotOre = precise.totalKWh > 0
                    ? (precise.totalCostKr / precise.totalKWh) * 100
                    : averagePrice
                let enhanced = totalCostService.calculateTotalCost(
                    kWh: precise.totalKWh,
                    spotPriceOre: effectiveSpotOre,
                    profile: profile,
                    hoursInPeriod: 730
                )
                return enhanced.totalKr
            } else {
                let enhanced = totalCostService.calculateTotalCost(
                    kWh: consumption.totalKWh,
                    spotPriceOre: averagePrice,
                    profile: profile,
                    hoursInPeriod: 730
                )
                return enhanced.totalKr
            }
        }
        return nil
    }

    private var liveCostForCurrentMonth: Double? {
        guard isCurrentMonth,
              let kWh = summary.totalConsumptionKWh, kWh > 0 else {
            return summary.totalCostSEK
        }
        let profile = ConsumptionSettings.shared.costProfile
        let spotOre = summary.averageSpotPriceOrePerKWh ?? 0
        let cost = totalCostService.calculateTotalCost(
            kWh: kWh,
            spotPriceOre: spotOre,
            profile: profile,
            hoursInPeriod: 730
        )
        return cost.totalKr
    }

    private func averagePriceMetric(_ summary: HistoricalEnergySummaryValue, liveCost: Double?) -> (title: String, value: String, unit: String) {
        if let cost = liveCost, let kWh = summary.totalConsumptionKWh, kWh > 0 {
            let avg = cost / kWh
            return (
                "Snitt totalpris",
                avg.formatted(.number.precision(.fractionLength(2))),
                "kr/kWh"
            )
        }
        if let totalPrice = summary.averageTotalCostSEKPerKWh {
            return (
                "Snitt totalpris",
                totalPrice.formatted(.number.precision(.fractionLength(2))),
                "kr/kWh"
            )
        }
        if let spotPrice = summary.averageSpotPriceOrePerKWh {
            return (
                "Snitt spotpris",
                AppFormatters.oreValue(spotPrice),
                "öre"
            )
        }
        return ("Snittpris", "-", "kr/kWh")
    }

}

// MARK: - History Lists

private struct HistoryTopDaysSection: View {
    let title: String
    let emptyMessage: String
    let days: [HistoricalEnergySummaryValue]
    var isCurrentMonth: Bool = false
    let value: (HistoricalEnergySummaryValue) -> (String, String)?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Font.headline)

            if days.isEmpty {
                Text(emptyMessage)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                ForEach(days) { day in
                    HistorySummaryRow(summary: day, value: value(day))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }
}

private struct HistoryDailyList: View {
    let days: [HistoricalEnergySummaryValue]
    @Binding var viewMode: HistoryMonthView.ViewMode
    @Binding var selectedDay: HistoricalEnergySummaryValue?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Alla sparade dagar")
                    .font(DS.Font.headline)

                Spacer()

                Picker("Visning", selection: $viewMode) {
                    Label("Graf", systemImage: "chart.bar.fill")
                        .tag(HistoryMonthView.ViewMode.chart)
                    Label("Tabell", systemImage: "list.bullet")
                        .tag(HistoryMonthView.ViewMode.table)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if days.isEmpty {
                Text("Inga dagar sparade för vald månad.")
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                switch viewMode {
                case .chart:
                    HistoryDailyChart(days: days, selectedDay: $selectedDay)
                case .table:
                    HistoryDailyTable(days: days)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }
}

private struct HistoryDailyChart: View {
    let days: [HistoricalEnergySummaryValue]
    @Binding var selectedDay: HistoricalEnergySummaryValue?

    private var sortedDays: [HistoricalEnergySummaryValue] {
        days.sorted { $0.periodStart < $1.periodStart }
    }

    private var hasMultipleCoverageTypes: Bool {
        Set(sortedDays.map(\.dataCoverage)).count > 1
    }

    /// A day reduced to a single plottable bar value, picking the most relevant
    /// metric available (cost, then consumption, then average price).
    private struct PlottableDay: Identifiable {
        let day: HistoricalEnergySummaryValue
        let value: Double
        let label: String
        var id: HistoricalEnergySummaryValue.ID { day.id }
    }

    /// Flattening the per-day metric selection here keeps the `Chart` body free of
    /// `if/else if` branches, whose `_ConditionalContent` conformance to `ChartContent`
    /// would otherwise require iOS 27.
    private var plottableDays: [PlottableDay] {
        sortedDays.compactMap { day in
            if let cost = day.totalCostSEK {
                return PlottableDay(day: day, value: cost, label: "Kostnad")
            } else if let consumption = day.totalConsumptionKWh {
                return PlottableDay(day: day, value: consumption, label: "Förbrukning")
            } else if let avgPrice = day.averageSpotPriceOrePerKWh {
                return PlottableDay(day: day, value: avgPrice / 100, label: "Snittpris")
            }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Chart {
                ForEach(plottableDays) { entry in
                    BarMark(
                        x: .value("Dag", entry.day.periodStart, unit: .day),
                        y: .value(entry.label, entry.value)
                    )
                    .foregroundStyle(coverageGradient(entry.day.dataCoverage))
                    .cornerRadius(4)
                    .opacity(selectedDay == nil || selectedDay?.id == entry.day.id ? 1.0 : 0.3)
                }

                if let selectedDay {
                    RuleMark(x: .value("Vald dag", selectedDay.periodStart))
                        .foregroundStyle(DS.Color.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: DS.Spacing.sm, overflowResolution: .init(x: .fit, y: .disabled)) {
                            HistoryDayCalloutView(day: selectedDay, showCoverageBadge: hasMultipleCoverageTypes)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: chartXAxisStride(for: sortedDays.count))) { value in
                    AxisGridLine()
                        .foregroundStyle(.tertiary)
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.day()))
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
            .frame(height: 200)
            .overlay {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectedDay = findNearestDay(
                                        at: value.location,
                                        in: sortedDays,
                                        chartWidth: geometry.size.width
                                    )
                                }
                                .onEnded { value in
                                    if value.translation.width < 5 && value.translation.height < 5 {
                                        selectedDay = nil
                                    }
                                }
                        )
                }
            }

            if hasMultipleCoverageTypes {
                HStack(spacing: DS.Spacing.lg) {
                    ForEach(HistoricalEnergyDataCoverage.allCases, id: \.self) { coverage in
                        if sortedDays.contains(where: { $0.dataCoverage == coverage }) {
                            HStack(spacing: DS.Spacing.xs) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(coverage.displayColor)
                                    .frame(width: 12, height: 12)
                                Text(coverage.displayTitle)
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func coverageGradient(_ coverage: HistoricalEnergyDataCoverage) -> LinearGradient {
        let color = coverage.displayColor
        return LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func chartXAxisStride(for dayCount: Int) -> Int {
        if dayCount <= 7 {
            return 1
        } else if dayCount <= 14 {
            return 2
        } else if dayCount <= 21 {
            return 3
        } else {
            return 5
        }
    }

    private func findNearestDay(
        at location: CGPoint,
        in days: [HistoricalEnergySummaryValue],
        chartWidth: CGFloat
    ) -> HistoricalEnergySummaryValue? {
        guard !days.isEmpty, chartWidth > 0 else { return nil }

        let dayIndex = Int((location.x / chartWidth) * Double(days.count))
        let clampedIndex = max(0, min(dayIndex, days.count - 1))

        return days[clampedIndex]
    }
}

private struct HistoryDailyTable: View {
    let days: [HistoricalEnergySummaryValue]

    var body: some View {
        ForEach(days) { day in
            HistorySummaryRow(summary: day, value: primaryValue(day))
        }
    }

    private func primaryValue(_ summary: HistoricalEnergySummaryValue) -> (String, String)? {
        if let cost = summary.totalCostSEK {
            return (AppFormatters.wholeNumber(cost), "kr")
        }
        if let consumption = summary.totalConsumptionKWh {
            return (AppFormatters.kWhValue(consumption), "kWh")
        }
        return summary.averageSpotPriceOrePerKWh.map { (AppFormatters.oreValue($0), "öre") }
    }
}

private struct HistorySummaryRow: View {
    let summary: HistoricalEnergySummaryValue
    let value: (String, String)?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(dayLabel(summary.periodStart))
                    .font(DS.Font.callout)
            }

            Spacer(minLength: DS.Spacing.sm)

            if let value {
                HStack(alignment: .center, spacing: DS.Spacing.xs) {
                    metricValue(value)

                    if let secondaryValue = secondaryValue(for: summary, primaryUnit: value.1) {
                        metricValue(secondaryValue)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            } else {
                Text("-")
                    .font(DS.Font.semibold(16).monospacedDigit())
                    .foregroundStyle(DS.Color.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func metricValue(_ value: (String, String)) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
            Text(value.0)
                .font(DS.Font.semibold(16).monospacedDigit())
            Text(value.1)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private func secondaryValue(for summary: HistoricalEnergySummaryValue, primaryUnit: String) -> (String, String)? {
        if primaryUnit != "kWh", let consumption = summary.totalConsumptionKWh {
            return (AppFormatters.kWhValue(consumption), "kWh")
        }
        if primaryUnit != "kr", let cost = summary.totalCostSEK {
            return (AppFormatters.wholeNumber(cost), "kr")
        }
        return nil
    }

    private func dayLabel(_ date: Date) -> String {
        AppFormatters.historyDayLabel(date)
    }
}

// MARK: - History Day Callout View

private struct HistoryDayCalloutView: View {
    let day: HistoricalEnergySummaryValue
    var showCoverageBadge: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme

    private var calloutBackground: Color {
        colorScheme == .dark ? Color(red: 0.08, green: 0.09, blue: 0.11) : Color.white
    }

    private var calloutStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.72)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header med datum och badge
            HStack(spacing: DS.Spacing.sm) {
                Text(dayLabel(day.periodStart))
                    .font(DS.Font.semibold(12))
                    .foregroundStyle(primaryTextColor)
                
                Spacer()
                
                // Coverage badge - bara visa om det finns variation i datasetet
                if showCoverageBadge {
                    Text(day.dataCoverage.calloutTitle)
                        .font(DS.Font.micro)
                        .foregroundStyle(day.dataCoverage.displayColor)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(day.dataCoverage.displayColor.opacity(0.15), in: Capsule())
                }
            }
            
            Divider()
                .padding(.vertical, DS.Spacing.xxs)
            
            // Metrics
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let cost = day.totalCostSEK {
                    metricRow(
                        icon: "wallet.bifold.fill",
                        label: "Kostnad",
                        value: AppFormatters.wholeNumber(cost),
                        unit: "kr",
                        highlight: true
                    )
                }
                
                if let consumption = day.totalConsumptionKWh {
                    metricRow(
                        icon: "bolt.fill",
                        label: "Förbrukning",
                        value: consumption.formatted(.number.precision(.fractionLength(1))),
                        unit: "kWh",
                        highlight: day.totalCostSEK == nil
                    )
                }
                
                if let avgPrice = day.averageSpotPriceOrePerKWh {
                    metricRow(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Snitt spotpris",
                        value: AppFormatters.oreValue(avgPrice),
                        unit: "öre/kWh",
                        highlight: false
                    )
                }
                
                // Visa pris per kWh om vi har både kostnad och förbrukning
                if let avgTotalPrice = day.averageTotalCostSEKPerKWh {
                    metricRow(
                        icon: "chart.bar.fill",
                        label: "Snitt totalpris",
                        value: avgTotalPrice.formatted(.number.precision(.fractionLength(2))),
                        unit: "kr/kWh",
                        highlight: false
                    )
                }
            }
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(calloutBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(calloutStroke, lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: DS.Spacing.sm, x: 0, y: DS.Spacing.xs)
    }
    
    private func metricRow(icon: String, label: String, value: String, unit: String, highlight: Bool) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(highlight ? primaryTextColor : secondaryTextColor)
                .frame(width: 12)
            
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(secondaryTextColor)
            
            Spacer()
            
            Text(value)
                .font(DS.Font.medium(11).monospacedDigit())
                .foregroundStyle(highlight ? primaryTextColor : secondaryTextColor)
            
            Text(unit)
                .font(DS.Font.micro)
                .foregroundStyle(secondaryTextColor)
        }
    }
    
    private func dayLabel(_ date: Date) -> String {
        AppFormatters.historyDayLabel(date)
    }
}

// MARK: - Preview Helper

#if DEBUG
private struct HistoryMonthView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            previewContainer(HistoryMonthView())
                .previewDisplayName("Med historik")

            previewContainer(emptyHistoryView)
                .previewDisplayName("Tom historik")

            previewContainer(measuredHistoryView)
                .previewDisplayName("Mock data - Mätt")

            previewContainer(mixedHistoryView)
                .previewDisplayName("Mock data - Blandat")
        }
    }

    private static var emptyHistoryView: some View {
        HistoryMonthView(previewState: .loaded(HistoryMonthView.HistoryData(
            months: [],
            selectedMonth: nil,
            dailySummaries: [],
            topCostDays: [],
            topConsumptionDays: []
        )))
    }

    private static var measuredHistoryView: some View {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let dailySummaries = measuredDailySummaries(calendar: calendar, monthStart: monthStart)
        let monthlySummary = HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.monthKey(for: now),
            periodStart: monthStart,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 720,
            measuredIntervalCount: 720,
            totalConsumptionKWh: dailySummaries.compactMap(\.totalConsumptionKWh).reduce(0, +),
            totalCostSEK: dailySummaries.compactMap(\.totalCostSEK).reduce(0, +),
            averageSpotPriceOrePerKWh: 75.5,
            minSpotPriceOrePerKWh: 20.0,
            maxSpotPriceOrePerKWh: 180.0,
            confidence: .measured
        )

        return historyView(monthlySummary: monthlySummary, dailySummaries: dailySummaries)
    }

    private static var mixedHistoryView: some View {
        let calendar = Calendar.energyHistory
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let dailySummaries = mixedDailySummaries(calendar: calendar, monthStart: monthStart)
        let monthlySummary = HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.monthKey(for: now),
            periodStart: monthStart,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 720,
            measuredIntervalCount: 360,
            totalConsumptionKWh: dailySummaries.compactMap(\.totalConsumptionKWh).reduce(0, +),
            totalCostSEK: dailySummaries.compactMap(\.totalCostSEK).reduce(0, +),
            averageSpotPriceOrePerKWh: 75.5,
            minSpotPriceOrePerKWh: 20.0,
            maxSpotPriceOrePerKWh: 180.0,
            confidence: .partial
        )

        return historyView(monthlySummary: monthlySummary, dailySummaries: dailySummaries)
    }

    private static func historyView(
        monthlySummary: HistoricalEnergySummaryValue,
        dailySummaries: [HistoricalEnergySummaryValue]
    ) -> some View {
        let topCost = Array(dailySummaries
            .filter { $0.totalCostSEK != nil }
            .sorted { ($0.totalCostSEK ?? 0) > ($1.totalCostSEK ?? 0) }
            .prefix(3))
        let topConsumption = Array(dailySummaries
            .filter { $0.totalConsumptionKWh != nil }
            .sorted { ($0.totalConsumptionKWh ?? 0) > ($1.totalConsumptionKWh ?? 0) }
            .prefix(3))

        return HistoryMonthView(previewState: .loaded(HistoryMonthView.HistoryData(
            months: [monthlySummary],
            selectedMonth: monthlySummary,
            dailySummaries: dailySummaries,
            topCostDays: topCost,
            topConsumptionDays: topConsumption
        )))
    }

    private static func measuredDailySummaries(
        calendar: Calendar,
        monthStart: Date
    ) -> [HistoricalEnergySummaryValue] {
        (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
            return dailySummary(
                date: date,
                measuredCount: 24,
                consumption: Double.random(in: 30...60),
                cost: Double.random(in: 150...350),
                confidence: .measured
            )
        }
    }

    private static func mixedDailySummaries(
        calendar: Calendar,
        monthStart: Date
    ) -> [HistoricalEnergySummaryValue] {
        (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!

            switch dayOffset % 4 {
            case 0:
                return dailySummary(
                    date: date,
                    measuredCount: 24,
                    consumption: Double.random(in: 30...60),
                    cost: Double.random(in: 150...350),
                    confidence: .measured
                )
            case 1:
                return dailySummary(
                    date: date,
                    measuredCount: 12,
                    consumption: Double.random(in: 30...60),
                    cost: Double.random(in: 150...350),
                    confidence: .partial
                )
            case 2:
                return dailySummary(
                    date: date,
                    measuredCount: 0,
                    consumption: nil,
                    cost: Double.random(in: 150...350),
                    confidence: .estimated
                )
            default:
                return dailySummary(
                    date: date,
                    measuredCount: 0,
                    consumption: nil,
                    cost: nil,
                    confidence: .priceOnly
                )
            }
        }
    }

    private static func dailySummary(
        date: Date,
        measuredCount: Int,
        consumption: Double?,
        cost: Double?,
        confidence: HistoricalEnergyConfidence
    ) -> HistoricalEnergySummaryValue {
        HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: EnergyHistoryKey.dayKey(for: date),
            periodStart: date,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 24,
            measuredIntervalCount: measuredCount,
            totalConsumptionKWh: consumption,
            totalCostSEK: cost,
            averageSpotPriceOrePerKWh: Double.random(in: 40...120),
            minSpotPriceOrePerKWh: Double.random(in: 20...60),
            maxSpotPriceOrePerKWh: Double.random(in: 80...180),
            confidence: confidence
        )
    }

    private static func previewContainer<Content: View>(_ content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}
#endif
