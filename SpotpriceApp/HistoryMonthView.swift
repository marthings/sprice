import SwiftUI
import Charts

struct HistoryMonthView: View {
    @State private var state: LoadState = .loading
    @State private var selectedMonthKey: String?
    @State private var viewMode: ViewMode = .chart
    @State private var selectedDay: HistoricalEnergySummaryValue?

    private let priceArea: String?
    private let calendar: Calendar
    
    // Preview support - allow injecting initial state
    private let initialState: LoadState?

    init(
        priceArea: String? = nil,
        calendar: Calendar = .energyHistory,
        previewState: LoadState? = nil
    ) {
        self.priceArea = priceArea
        self.calendar = calendar
        self.initialState = previewState
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
                historyStatus(
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
            historyStatus(
                icon: "clock.badge",
                title: "Ingen sparad historik än",
                message: "Historik fylls på automatiskt efter lyckade prisuppdateringar. Förbrukning och kostnad visas när sådan data finns sparad.",
                color: DS.Color.secondary
            )
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                monthPicker(data.months)

                if let selectedMonth = data.selectedMonth {
                    monthSummary(selectedMonth)
                }

                topDaysSection(
                    title: "Dyraste dagar",
                    emptyMessage: "Kostnadsdagar visas när historiken innehåller beräknad kostnad.",
                    days: data.topCostDays,
                    value: { summary in
                        summary.totalCostSEK.map { (Int($0.rounded()).formatted(), "kr") }
                    }
                )

                topDaysSection(
                    title: "Högst förbrukning",
                    emptyMessage: "Förbrukningsdagar visas när en datakälla har levererat mätvärden.",
                    days: data.topConsumptionDays,
                    value: { summary in
                        summary.totalConsumptionKWh.map { ($0.formatted(.number.precision(.fractionLength(0...1))), "kWh") }
                    }
                )

                dailyHistoryList(data.dailySummaries)
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

    private func monthSummary(_ summary: HistoricalEnergySummaryValue) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                metricCard(
                    title: "Kostnad",
                    value: summary.totalCostSEK.map { Int($0.rounded()).formatted() } ?? "-",
                    unit: "kr",
                    icon: "wallet.bifold.fill"
                )
                metricCard(
                    title: "Förbrukning",
                    value: summary.totalConsumptionKWh.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "-",
                    unit: "kWh",
                    icon: "bolt.fill"
                )
            }

            HStack(spacing: DS.Spacing.sm) {
                let averagePriceMetric = averagePriceMetric(summary)
                metricCard(
                    title: averagePriceMetric.title,
                    value: averagePriceMetric.value,
                    unit: averagePriceMetric.unit,
                    icon: "chart.line.uptrend.xyaxis"
                )
                metricCard(
                    title: "Dagar",
                    value: monthDayCount(summary).formatted(),
                    unit: "st",
                    icon: "calendar"
                )
            }
        }
    }

    private func metricCard(title: String, value: String, unit: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                .foregroundStyle(DS.Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(value)
                        .font(DS.Font.bold(20).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(unit)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .glassCard(cornerRadius: DS.Radius.md)
    }

    private func topDaysSection(
        title: String,
        emptyMessage: String,
        days: [HistoricalEnergySummaryValue],
        value: @escaping (HistoricalEnergySummaryValue) -> (String, String)?
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            
            Text(title)
                .font(DS.Font.headline)

            if days.isEmpty {
                Text(emptyMessage)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
            } else {
                ForEach(days) { day in
                    historyRow(summary: day, value: value(day))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }

    private func dailyHistoryList(_ days: [HistoricalEnergySummaryValue]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Alla sparade dagar")
                    .font(DS.Font.headline)
                
                Spacer()
                
                Picker("Visning", selection: $viewMode) {
                    Label("Graf", systemImage: "chart.bar.fill")
                        .tag(ViewMode.chart)
                    Label("Tabell", systemImage: "list.bullet")
                        .tag(ViewMode.table)
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
                    dailyHistoryChart(days)
                case .table:
                    dailyHistoryTable(days)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }

    @ViewBuilder
    private func dailyHistoryChart(_ days: [HistoricalEnergySummaryValue]) -> some View {
        let sortedDays = days.sorted { $0.periodStart < $1.periodStart }
        let hasMultipleCoverageTypes = Set(sortedDays.map(\.dataCoverage)).count > 1
        
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Chart {
                ForEach(sortedDays) { day in
                    if let cost = day.totalCostSEK {
                        BarMark(
                            x: .value("Dag", day.periodStart, unit: .day),
                            y: .value("Kostnad", cost)
                        )
                        .foregroundStyle(coverageGradient(day.dataCoverage))
                        .cornerRadius(4)
                        .opacity(selectedDay == nil || selectedDay?.id == day.id ? 1.0 : 0.3)
                    } else if let consumption = day.totalConsumptionKWh {
                        BarMark(
                            x: .value("Dag", day.periodStart, unit: .day),
                            y: .value("Förbrukning", consumption)
                        )
                        .foregroundStyle(coverageGradient(day.dataCoverage))
                        .cornerRadius(4)
                        .opacity(selectedDay == nil || selectedDay?.id == day.id ? 1.0 : 0.3)
                    } else if let avgPrice = day.averageSpotPriceOrePerKWh {
                        BarMark(
                            x: .value("Dag", day.periodStart, unit: .day),
                            y: .value("Snittpris", avgPrice / 100)
                        )
                        .foregroundStyle(coverageGradient(day.dataCoverage))
                        .cornerRadius(4)
                        .opacity(selectedDay == nil || selectedDay?.id == day.id ? 1.0 : 0.3)
                    }
                }
                
                // Selection indicator with callout
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
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectedDay = findNearestDay(at: value.location, in: sortedDays)
                    }
                    .onEnded { value in
                        // If it was just a tap (minimal movement), toggle selection
                        if value.translation.width < 5 && value.translation.height < 5 {
                            // Tap detected - clear selection
                            selectedDay = nil
                        }
                        // Otherwise keep the selection from drag
                    }
            )
            
            // Legend - bara visa om det finns variation
            if hasMultipleCoverageTypes {
                HStack(spacing: DS.Spacing.lg) {
                    ForEach(HistoricalEnergyDataCoverage.allCases, id: \.self) { coverage in
                        if sortedDays.contains(where: { $0.dataCoverage == coverage }) {
                            HStack(spacing: DS.Spacing.xs) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(coverageColor(coverage))
                                    .frame(width: 12, height: 12)
                                Text(coverageTitle(coverage))
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func dailyHistoryTable(_ days: [HistoricalEnergySummaryValue]) -> some View {
        ForEach(days) { day in
            historyRow(summary: day, value: primaryValue(day))
        }
    }

    private func historyRow(
        summary: HistoricalEnergySummaryValue,
        value: (String, String)?
    ) -> some View {
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

    private func coverageLabel(_ summary: HistoricalEnergySummaryValue) -> some View {
        Text(coverageTitle(summary))
            .font(DS.Font.micro)
            .foregroundStyle(coverageColor(summary))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(coverageColor(summary).opacity(0.12), in: Capsule())
    }

    private func historyStatus(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Font.callout)
                Text(message)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.lg)
        .glassCard(cornerRadius: DS.Radius.lg)
    }

    @MainActor
    private func loadHistory() async {
        do {
            let activePriceArea = priceArea ?? ConsumptionSettings.shared.priceArea
            let store = try SwiftDataEnergyHistoryStore()
            let months = uniqueBestMonthlySummaries(
                try store.fetchMonthlySummaries(priceArea: activePriceArea)
            )
            let selectedKey = selectedMonthKey ?? months.first?.periodKey
            let dailySummaries: [HistoricalEnergySummaryValue]
            let topCostDays: [HistoricalEnergySummaryValue]
            let topConsumptionDays: [HistoricalEnergySummaryValue]

            if let selectedKey {
                selectedMonthKey = selectedKey
                dailySummaries = try store.fetchDailySummaries(monthKey: selectedKey, priceArea: activePriceArea)
                    .sorted { $0.periodStart > $1.periodStart }
                topCostDays = try store.fetchTopCostDays(monthKey: selectedKey, priceArea: activePriceArea, limit: 3)
                topConsumptionDays = try store.fetchTopConsumptionDays(monthKey: selectedKey, priceArea: activePriceArea, limit: 3)
            } else {
                dailySummaries = []
                topCostDays = []
                topConsumptionDays = []
            }

            state = .loaded(HistoryData(
                months: months,
                selectedMonth: months.first { $0.periodKey == selectedKey },
                dailySummaries: dailySummaries,
                topCostDays: topCostDays,
                topConsumptionDays: topConsumptionDays
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func primaryValue(_ summary: HistoricalEnergySummaryValue) -> (String, String)? {
        if let cost = summary.totalCostSEK {
            return (Int(cost.rounded()).formatted(), "kr")
        }
        if let consumption = summary.totalConsumptionKWh {
            return (consumption.formatted(.number.precision(.fractionLength(0...1))), "kWh")
        }
        return summary.averageSpotPriceOrePerKWh.map { (Int($0.rounded()).formatted(), "öre") }
    }

    private func averagePriceMetric(_ summary: HistoricalEnergySummaryValue) -> (title: String, value: String, unit: String) {
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
                Int(spotPrice.rounded()).formatted(),
                "öre"
            )
        }
        return ("Snittpris", "-", "kr/kWh")
    }

    private func secondaryValue(for summary: HistoricalEnergySummaryValue, primaryUnit: String) -> (String, String)? {
        if primaryUnit != "kWh", let consumption = summary.totalConsumptionKWh {
            return (consumption.formatted(.number.precision(.fractionLength(0...1))), "kWh")
        }
        if primaryUnit != "kr", let cost = summary.totalCostSEK {
            return (Int(cost.rounded()).formatted(), "kr")
        }
        return nil
    }

    private func uniqueBestMonthlySummaries(_ summaries: [HistoricalEnergySummaryValue]) -> [HistoricalEnergySummaryValue] {
        Dictionary(grouping: summaries, by: \.periodKey)
            .compactMap { _, summaries in
                summaries.sorted { lhs, rhs in
                    let lhsRank = summaryRank(lhs)
                    let rhsRank = summaryRank(rhs)
                    if lhsRank == rhsRank {
                        return lhs.intervalCount > rhs.intervalCount
                    }
                    return lhsRank > rhsRank
                }
                .first
            }
            .sorted { $0.periodStart > $1.periodStart }
    }

    private func summaryRank(_ summary: HistoricalEnergySummaryValue) -> Int {
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

    private func monthDayCount(_ summary: HistoricalEnergySummaryValue) -> Int {
        Calendar.energyHistory.range(of: .day, in: .month, for: summary.periodStart)?.count ?? 0
    }

    private func coverageTitle(_ summary: HistoricalEnergySummaryValue) -> String {
        coverageTitle(summary.dataCoverage)
    }

    private func coverageTitle(_ coverage: HistoricalEnergyDataCoverage) -> String {
        switch coverage {
        case .priceOnly:
            return "Pris"
        case .estimatedCost:
            return "Uppskattat"
        case .partialConsumption:
            return "Delvis mätt"
        case .measuredConsumption:
            return "Mätt"
        }
    }

    private func coverageText(_ summary: HistoricalEnergySummaryValue) -> String {
        switch summary.dataCoverage {
        case .priceOnly:
            return "Spotpriser sparade"
        case .estimatedCost:
            return "Kostnad beräknad utan mätt förbrukning"
        case .partialConsumption:
            if let ratio = summary.measuredCoverageRatio {
                let percent = ratio.formatted(.percent.precision(.fractionLength(0)))
                return "Mätt förbrukning: \(percent)"
            }
            return "Delvis mätt förbrukning"
        case .measuredConsumption:
            return "Mätt förbrukning och kostnad"
        }
    }

    private func coverageColor(_ summary: HistoricalEnergySummaryValue) -> Color {
        coverageColor(summary.dataCoverage)
    }

    private func coverageColor(_ coverage: HistoricalEnergyDataCoverage) -> Color {
        switch coverage {
        case .priceOnly:
            return DS.Color.secondary
        case .estimatedCost:
            return DS.Color.warning
        case .partialConsumption:
            return DS.Color.info
        case .measuredConsumption:
            return DS.Color.success
        }
    }

    private func coverageGradient(_ coverage: HistoricalEnergyDataCoverage) -> LinearGradient {
        let color = coverageColor(coverage)
        return LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func chartXAxisStride(for dayCount: Int) -> Int {
        if dayCount <= 7 {
            return 1 // Visa varje dag
        } else if dayCount <= 14 {
            return 2 // Varannan dag
        } else if dayCount <= 21 {
            return 3 // Var tredje dag
        } else {
            return 5 // Var femte dag
        }
    }

    private func findNearestDay(at location: CGPoint, in days: [HistoricalEnergySummaryValue]) -> HistoricalEnergySummaryValue? {
        guard !days.isEmpty else { return nil }
        
        // Approximate calculation - assumes chart width is proportional to screen width
        // This is a simplified version; for production you'd want to use chartProxy
        let dayIndex = Int((location.x / 300) * Double(days.count))
        let clampedIndex = max(0, min(dayIndex, days.count - 1))
        
        return days[clampedIndex]
    }

    private func monthLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "sv_SE")))
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "sv_SE")))
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
    
    private var coverageColor: Color {
        switch day.dataCoverage {
        case .priceOnly:
            return DS.Color.secondary
        case .estimatedCost:
            return DS.Color.warning
        case .partialConsumption:
            return DS.Color.info
        case .measuredConsumption:
            return DS.Color.success
        }
    }
    
    private var coverageLabel: String {
        switch day.dataCoverage {
        case .priceOnly:
            return "Bara pris"
        case .estimatedCost:
            return "Uppskattat"
        case .partialConsumption:
            return "Delvis mätt"
        case .measuredConsumption:
            return "Mätt"
        }
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
                    Text(coverageLabel)
                        .font(DS.Font.micro)
                        .foregroundStyle(coverageColor)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(coverageColor.opacity(0.15), in: Capsule())
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
                        value: Int(cost.rounded()).formatted(),
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
                        value: Int(avgPrice.rounded()).formatted(),
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
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "sv_SE")))
    }
}

// MARK: - Preview Helper

#Preview("Med historik") {
    HistoryMonthView()
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Tom historik") {
    HistoryMonthView(previewState: .loaded(HistoryMonthView.HistoryData(
        months: [],
        selectedMonth: nil,
        dailySummaries: [],
        topCostDays: [],
        topConsumptionDays: []
    )))
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Mock data - Mätt") {
    let calendar = Calendar.energyHistory
    let now = Date()
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
    
    // Skapa 30 dagars mock-data
    let dailySummaries = (0..<30).map { dayOffset -> HistoricalEnergySummaryValue in
        let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
        let dayKey = EnergyHistoryKey.dayKey(for: date)
        let monthKey = EnergyHistoryKey.monthKey(for: date)
        
        // Variera kostnad och förbrukning lite
        let baseCost = Double.random(in: 150...350)
        let baseConsumption = Double.random(in: 30...60)
        
        return HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: dayKey,
            periodStart: date,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 24,
            measuredIntervalCount: 24,
            totalConsumptionKWh: baseConsumption,
            totalCostSEK: baseCost,
            averageSpotPriceOrePerKWh: Double.random(in: 40...120),
            minSpotPriceOrePerKWh: Double.random(in: 20...60),
            maxSpotPriceOrePerKWh: Double.random(in: 80...180),
            confidence: .measured
        )
    }
    
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
    
    let topCost = Array(dailySummaries.sorted { ($0.totalCostSEK ?? 0) > ($1.totalCostSEK ?? 0) }.prefix(3))
    let topConsumption = Array(dailySummaries.sorted { ($0.totalConsumptionKWh ?? 0) > ($1.totalConsumptionKWh ?? 0) }.prefix(3))
    
    HistoryMonthView(previewState: .loaded(HistoryMonthView.HistoryData(
        months: [monthlySummary],
        selectedMonth: monthlySummary,
        dailySummaries: dailySummaries,
        topCostDays: topCost,
        topConsumptionDays: topConsumption
    )))
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Mock data - Blandat") {
    let calendar = Calendar.energyHistory
    let now = Date()
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
    
    // Skapa 30 dagars mock-data med olika coverage-typer
    let dailySummaries = (0..<30).map { dayOffset -> HistoricalEnergySummaryValue in
        let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
        let dayKey = EnergyHistoryKey.dayKey(for: date)
        
        // Blanda olika coverage-typer
        let coverage: HistoricalEnergyDataCoverage
        let confidence: HistoricalEnergyConfidence
        let measuredCount: Int
        let hasCost: Bool
        let hasConsumption: Bool
        
        switch dayOffset % 4 {
        case 0: // Mätt
            coverage = .measuredConsumption
            confidence = .measured
            measuredCount = 24
            hasCost = true
            hasConsumption = true
        case 1: // Delvis mätt
            coverage = .partialConsumption
            confidence = .partial
            measuredCount = 12
            hasCost = true
            hasConsumption = true
        case 2: // Uppskattat
            coverage = .estimatedCost
            confidence = .estimated
            measuredCount = 0
            hasCost = true
            hasConsumption = false
        default: // Bara pris
            coverage = .priceOnly
            confidence = .priceOnly
            measuredCount = 0
            hasCost = false
            hasConsumption = false
        }
        
        return HistoricalEnergySummaryValue(
            id: UUID(),
            periodKey: dayKey,
            periodStart: date,
            priceArea: "SE3",
            providerID: "tibber",
            intervalCount: 24,
            measuredIntervalCount: measuredCount,
            totalConsumptionKWh: hasConsumption ? Double.random(in: 30...60) : nil,
            totalCostSEK: hasCost ? Double.random(in: 150...350) : nil,
            averageSpotPriceOrePerKWh: Double.random(in: 40...120),
            minSpotPriceOrePerKWh: Double.random(in: 20...60),
            maxSpotPriceOrePerKWh: Double.random(in: 80...180),
            confidence: confidence
        )
    }
    
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
    
    let topCost = Array(dailySummaries.filter { $0.totalCostSEK != nil }.sorted { ($0.totalCostSEK ?? 0) > ($1.totalCostSEK ?? 0) }.prefix(3))
    let topConsumption = Array(dailySummaries.filter { $0.totalConsumptionKWh != nil }.sorted { ($0.totalConsumptionKWh ?? 0) > ($1.totalConsumptionKWh ?? 0) }.prefix(3))
    
    HistoryMonthView(previewState: .loaded(HistoryMonthView.HistoryData(
        months: [monthlySummary],
        selectedMonth: monthlySummary,
        dailySummaries: dailySummaries,
        topCostDays: topCost,
        topConsumptionDays: topConsumption
    )))
    .padding()
    .background(Color(.systemGroupedBackground))
}
