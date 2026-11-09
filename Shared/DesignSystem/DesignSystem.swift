//
//  DesignSystem.swift
//  Spotprice
//
//  Shared design tokens for app and widget
//

import SwiftUI
import CoreText
#if os(iOS)
import UIKit
#endif

// MARK: - Shared Formatters

enum AppFormatters {
    nonisolated static let swedishLocale = Locale(identifier: "sv_SE")
    nonisolated static let swedishTimeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
    nonisolated static let posixLocale = Locale(identifier: "en_US_POSIX")

    nonisolated static let energyCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = swedishLocale
        calendar.timeZone = swedishTimeZone
        return calendar
    }()

    private static let swedishDate = Date.FormatStyle(
        date: .omitted,
        time: .omitted,
        locale: swedishLocale,
        calendar: energyCalendar,
        timeZone: swedishTimeZone
    )

    static func monthAndYear(_ date: Date) -> String {
        date.formatted(swedishDate.month(.wide).year())
    }

    static func monthName(_ date: Date) -> String {
        date.formatted(swedishDate.month(.wide))
    }

    static func shortDayAndMonth(_ date: Date) -> String {
        date.formatted(swedishDate.day().month(.abbreviated))
    }

    static func powerPeakLabel(_ date: Date) -> String {
        date.formatted(swedishDate.day().month(.abbreviated).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func powerPeakHourLabel(_ date: Date) -> String {
        date.formatted(swedishDate.day().month(.abbreviated).hour(.defaultDigits(amPM: .omitted)))
    }

    static func widgetMonthLabel(_ date: Date) -> String {
        date.formatted(swedishDate.month(.abbreviated))
    }

    static func clockTime(_ date: Date) -> String {
        date.formatted(swedishDate.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }

    static func apiDate(_ date: Date) -> String {
        apiDateFormatter.string(from: date)
    }

    static func apiDateTime(_ date: Date) -> String {
        apiDateTimeFormatter.string(from: date)
    }

    static func historyMonthLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(swedishLocale))
    }

    static func historyDayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(swedishLocale))
    }

    static func weekdayDayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(swedishLocale))
    }

    nonisolated static func csvNumber(_ value: Double) -> String {
        value.formatted(.number.locale(posixLocale).precision(.fractionLength(0...6)))
    }

    static func wholeKr(_ value: Double) -> String {
        "\(Int(value.rounded()).formatted()) kr"
    }

    static func wholeNumber(_ value: Double) -> String {
        Int(value.rounded()).formatted()
    }

    static func kr(_ value: Double, fractionLength: Int = 0) -> String {
        "\(value.formatted(.number.precision(.fractionLength(fractionLength)))) kr"
    }

    static func kWhValue(_ value: Double, fractionLength: ClosedRange<Int> = 0...1) -> String {
        value.formatted(.number.precision(.fractionLength(fractionLength)))
    }

    static func kWh(_ value: Double, fractionLength: ClosedRange<Int> = 0...1) -> String {
        "\(kWhValue(value, fractionLength: fractionLength)) kWh"
    }

    static func oreValue(_ value: Double) -> String {
        Int(value.rounded()).formatted()
    }

    static func ore(_ value: Double) -> String {
        "\(oreValue(value)) öre"
    }

    static func krPerKWh(_ value: Double, fractionLength: Int = 2) -> String {
        "\(value.formatted(.number.precision(.fractionLength(fractionLength)))) kr/kWh"
    }

    static func decimalNumberFormatter(maximumFractionDigits: Int = 1) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0
        return formatter
    }

    static func vaggerydDateDecoder() -> JSONDecoder {
        vaggerydJSONDecoder
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = energyCalendar
        formatter.locale = posixLocale
        formatter.timeZone = swedishTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let apiDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = energyCalendar
        formatter.locale = posixLocale
        formatter.timeZone = swedishTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let vaggerydJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.calendar = energyCalendar
        formatter.locale = posixLocale
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = swedishTimeZone
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}

// MARK: - Design System

enum DS {

    // MARK: - Typography

    enum Font {
        /// Widget extensions don't reliably honor `UIAppFonts`/`ATSApplicationFontsPath`,
        /// so widget entry points register the bundled fonts with CoreText explicitly.
        static func registerBundledFonts() {
            _ = registration
        }

        private static let registration: Void = {
            for resource in ["osans-regular", "osans-heavy"] {
                guard let url = Bundle.main.url(forResource: resource, withExtension: "otf") else { continue }
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }()

        static func regular(_ size: CGFloat) -> SwiftUI.Font {
            .custom("PPObjectSans-Regular", size: size)
        }

        static func medium(_ size: CGFloat) -> SwiftUI.Font {
            .custom("PPObjectSans-Regular", size: size).weight(.medium)
        }

        static func semibold(_ size: CGFloat) -> SwiftUI.Font {
            .custom("PPObjectSans-Heavy", size: size)
        }

        static func bold(_ size: CGFloat) -> SwiftUI.Font {
            .custom("PPObjectSans-Heavy", size: size)
        }

        // Preset sizes
        static let largeTitle = bold(32)
        static let title = bold(20)
        static let headline = semibold(17)
        static let body = regular(15)
        static let callout = medium(14)
        static let caption = medium(12)
        static let micro = medium(11)

        #if os(iOS)
        /// Navigation titles can't take a SwiftUI `Font`, so UIKit chrome uses this.
        static func configureNavigationBarAppearance() {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: uiHeavy(size: 17, textStyle: .headline),
                .foregroundColor: UIColor.label
            ]
            let largeTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: uiHeavy(size: 34, textStyle: .largeTitle),
                .foregroundColor: UIColor.label
            ]

            let standard = UINavigationBarAppearance()
            standard.configureWithDefaultBackground()
            standard.titleTextAttributes = titleAttributes
            standard.largeTitleTextAttributes = largeTitleAttributes

            let scrollEdge = UINavigationBarAppearance()
            scrollEdge.configureWithTransparentBackground()
            scrollEdge.titleTextAttributes = titleAttributes
            scrollEdge.largeTitleTextAttributes = largeTitleAttributes

            let compact = UINavigationBarAppearance()
            compact.configureWithDefaultBackground()
            compact.titleTextAttributes = titleAttributes
            compact.largeTitleTextAttributes = largeTitleAttributes

            let navigationBar = UINavigationBar.appearance()
            navigationBar.standardAppearance = standard
            navigationBar.scrollEdgeAppearance = scrollEdge
            navigationBar.compactAppearance = compact
        }

        private static func uiHeavy(size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
            let base = UIFont(name: "PPObjectSans-Heavy", size: size)
                ?? .systemFont(ofSize: size, weight: .heavy)
            return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
        }
        #endif
    }

    // MARK: - Semantic Colors

    enum Color {
        // Semantic colors from assets (auto light/dark)
        static let brand = SwiftUI.Color("BrandColor")
        static let success = SwiftUI.Color("SuccessColor")
        static let info = SwiftUI.Color("InfoColor")
        static let warning = SwiftUI.Color("WarningColor")
        static let danger = SwiftUI.Color("DangerColor")

        static let secondary = SwiftUI.Color.primary.opacity(0.72)
        static let outline = SwiftUI.Color.primary.opacity(0.28)

        static func forCategory(_ category: PriceCategory) -> SwiftUI.Color {
            switch category {
            case .low: return success
            case .medium: return warning
            case .high: return danger
            }
        }

        /// Returns a color based on where the price falls in the day's range
        /// - Parameters:
        ///   - price: Current price
        ///   - min: Day's minimum price
        ///   - max: Day's maximum price
        /// - Returns: Green for low, yellow/orange for medium, red for high
        static func forPrice(_ price: Double, min: Double, max: Double) -> SwiftUI.Color {
            forCategory(categoryForPrice(price, min: min, max: max))
        }

        /// Returns a PriceCategory based on where the price falls in the day's range
        static func categoryForPrice(_ price: Double, min: Double, max: Double) -> PriceCategory {
            let range = max - min
            guard range > 0 else { return .medium }

            let normalized = (price - min) / range

            if normalized <= 0.33 {
                return .low
            } else if normalized <= 0.66 {
                return .medium
            } else {
                return .high
            }
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        /// Space from a navigation title down to the first content on iOS tabs
        /// and pushed screens. Tight but not flush; Form screens use the same
        /// value via `contentMargins` so they match ScrollView padding.
        static let titleToContent: CGFloat = 10
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let full: CGFloat = 999
    }

    // MARK: - Glass Effects (iOS 26 / macOS 26)

    enum Glass {
        /// Standard corner radius for glass cards
        static let cardRadius: CGFloat = Radius.xl
        /// Corner radius for small glass elements
        static let smallRadius: CGFloat = Radius.md
    }

    // MARK: - Component Sizes

    enum Size {
        // Menu Bar
        static let menuBarWidth: CGFloat = 360
        static let menuBarHeight: CGFloat = 720
        
        // Settings
        static let settingsSidebarMinWidth: CGFloat = 168
        static let settingsSidebarWidth: CGFloat = 196
        static let settingsSidebarMaxWidth: CGFloat = 220
        static let settingsMinWidth: CGFloat = 560
        static let settingsWidth: CGFloat = 640
        static let settingsMinHeight: CGFloat = 480
        static let settingsHeight: CGFloat = 520
        static let settingsFieldWidth: CGFloat = 160

        // Charts
        static let chartHeightMenuBar: CGFloat = 220
        static let chartHeightFull: CGFloat = 200
        static let chartHeightWidget: CGFloat = 80

        // Icons
        static let iconSmall: CGFloat = 14
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 28
        static let iconXL: CGFloat = 36

        // Cards
        static let statCardIconSize: CGFloat = 24
        static let headerIconSize: CGFloat = 28

        // Buttons
        static let closeButtonSize: CGFloat = 32
        static let closeButtonIconSize: CGFloat = 11
    }

    struct PrimaryButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Font.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Color.brand.opacity(isEnabled ? 1 : 0.45),
                    in: .rect(cornerRadius: Radius.md)
                )
                .opacity(configuration.isPressed ? 0.82 : 1)
        }
    }
}

// MARK: - Historical Energy Coverage Presentation

enum HistoricalEnergyCoverageTextStyle {
    case compact
    case fallback
    case brandedMonthly
}

extension HistoricalEnergyDataCoverage {
    var displayTitle: String {
        switch self {
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

    var calloutTitle: String {
        switch self {
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

    var displayColor: Color {
        switch self {
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
}

extension HistoricalEnergySummaryValue {
    func coverageText(style: HistoricalEnergyCoverageTextStyle) -> String {
        switch style {
        case .compact:
            return compactCoverageText
        case .fallback:
            return fallbackCoverageText
        case .brandedMonthly:
            return brandedMonthlyCoverageText
        }
    }

    private var compactCoverageText: String {
        switch dataCoverage {
        case .priceOnly:
            return "Spotpriser sparade"
        case .estimatedCost:
            return "Kostnad beräknad utan mätt förbrukning"
        case .partialConsumption:
            if let ratio = measuredCoverageRatio {
                return "Mätt förbrukning: \(coveragePercent(ratio))"
            }
            return "Delvis mätt förbrukning"
        case .measuredConsumption:
            return "Mätt förbrukning och kostnad"
        }
    }

    private var fallbackCoverageText: String {
        switch dataCoverage {
        case .priceOnly:
            return "Förbrukningsdata saknas. Visar sparad prishistorik."
        case .estimatedCost:
            return "Förbrukningsdata saknas. Visar sparad uppskattad kostnad."
        case .partialConsumption:
            if let ratio = measuredCoverageRatio {
                return "Förbrukningsdata saknas. Historiken täcker \(coveragePercent(ratio)) av intervallen."
            }
            return "Förbrukningsdata saknas. Visar delvis mätt historik."
        case .measuredConsumption:
            return "Förbrukningsdata saknas. Visar sparad mätt förbrukning."
        }
    }

    private var brandedMonthlyCoverageText: String {
        switch dataCoverage {
        case .priceOnly:
            return "Förbrukningsdata saknas. Sprice visar sparade spotpriser för månaden."
        case .estimatedCost:
            return "Förbrukningsdata saknas. Sprice visar sparad uppskattad kostnad för månaden."
        case .partialConsumption:
            if let ratio = measuredCoverageRatio {
                return "Förbrukningsdata saknas. Sparad historik har mätt förbrukning för \(coveragePercent(ratio)) av intervallen."
            }
            return "Liveförbrukning saknas. Sprice visar delvis mätt sparad historik."
        case .measuredConsumption:
            return "Förbrukningsdata saknas. Sprice visar sparad mätt förbrukning och kostnad."
        }
    }

    private func coveragePercent(_ ratio: Double) -> String {
        ratio.formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: - Reusable Price Components

struct AppStatusRow: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    var trailingIcon: String?
    var titleFont: Font = DS.Font.callout
    var messageLineLimit: Int?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconMedium, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                Text(message)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .lineLimit(messageLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondary)
            }
        }
    }
}

struct AppStatusCard: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    var trailingIcon: String?
    var interactive = false
    var messageLineLimit: Int?

    var body: some View {
        AppStatusRow(
            icon: icon,
            title: title,
            message: message,
            color: color,
            trailingIcon: trailingIcon,
            messageLineLimit: messageLineLimit
        )
        .padding(DS.Spacing.lg)
        .spriceCard(tone: .default, interactive: interactive)
    }
}

struct HistoryCoverageBadge: View {
    let coverage: HistoricalEnergyDataCoverage
    var horizontalPadding: CGFloat = DS.Spacing.sm

    var body: some View {
        Text(coverage.displayTitle)
            .font(DS.Font.micro)
            .foregroundStyle(coverage.displayColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, DS.Spacing.xxs)
            .background(coverage.displayColor.opacity(0.12), in: Capsule())
    }
}

struct CostPrecisionNote: View {
    let cost: PreciseMonthlyCost

    private var matchedRatio: Double {
        cost.totalIntervals > 0 ? Double(cost.matchedIntervals) / Double(cost.totalIntervals) : 0
    }

    var body: some View {
        Label(
            "Beräknat från faktisk förbrukning och matchade spotpriser: \(matchedRatio.formatted(.percent.precision(.fractionLength(0)))).",
            systemImage: "checkmark.seal.fill"
        )
        .font(DS.Font.micro)
        .foregroundStyle(DS.Color.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SharedCostBreakdownRow: View {
    let label: String
    let amount: Double
    let color: Color
    var style: Style = .compact

    enum Style {
        case compact
        case regular

        var dotSize: CGFloat {
            switch self {
            case .compact: return 6
            case .regular: return 8
            }
        }

        var dotOpacity: Double {
            switch self {
            case .compact: return 0.3
            case .regular: return 1.0
            }
        }

        var labelFont: Font {
            switch self {
            case .compact: return DS.Font.medium(11)
            case .regular: return DS.Font.callout
            }
        }

        var amountFont: Font {
            switch self {
            case .compact: return DS.Font.medium(11).monospacedDigit()
            case .regular: return DS.Font.semibold(14).monospacedDigit()
            }
        }
    }

    var body: some View {
        HStack(spacing: style == .compact ? DS.Spacing.xs : DS.Spacing.sm) {
            Circle()
                .fill(color.opacity(style.dotOpacity))
                .frame(width: style.dotSize, height: style.dotSize)

            Text(label)
                .font(style.labelFont)
                .foregroundStyle(.primary)

            Spacer(minLength: style == .compact ? 0 : DS.Spacing.sm)

            Text(AppFormatters.wholeKr(amount))
                .font(style.amountFont)
                .foregroundStyle(.primary)
        }
    }
}

struct SharedCostBreakdownSubRow: View {
    let label: String
    let amount: Double
    var leadingPadding: CGFloat = 14

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.regular(10))
                .foregroundStyle(DS.Color.secondary)
                .padding(.leading, leadingPadding)

            Spacer()

            Text(AppFormatters.wholeKr(amount))
                .font(DS.Font.regular(10).monospacedDigit())
                .foregroundStyle(DS.Color.secondary)
        }
    }
}

struct MetricCard: View {
    enum Layout {
        case horizontal
        case vertical
    }

    let title: String
    let value: String
    let unit: String
    var icon: String? = nil
    var color: Color = .primary
    var titleColor: Color = DS.Color.secondary
    var valueFont: Font = DS.Font.bold(20).monospacedDigit()
    var unitFont: Font = DS.Font.micro
    var iconSize: CGFloat = DS.Size.iconMedium
    var layout: Layout = .horizontal
    var subtitle: String? = nil

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                horizontalContent
            case .vertical:
                verticalContent
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var horizontalContent: some View {
        HStack(spacing: DS.Spacing.md) {
            iconView(width: 28)
            textContent(alignment: .leading)
            Spacer(minLength: 0)
        }
    }

    private var verticalContent: some View {
        VStack(spacing: DS.Spacing.xs) {
            iconView(width: nil)
            textContent(alignment: .center)
        }
    }

    @ViewBuilder
    private func iconView(width: CGFloat?) -> some View {
        if let icon {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: width)
        }
    }

    private func textContent(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Font.micro)
                .foregroundStyle(titleColor)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .lineLimit(layout == .horizontal ? 1 : nil)

            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(valueFont)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(DS.Color.secondary)
            }

            if let subtitle {
                Text(subtitle)
                    .font(DS.Font.micro)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }
}

struct PriceDisplay: View {
    let price: Int
    let category: PriceCategory
    let size: Size
    var useSemanticColor: Bool = true

    enum Size {
        case small, medium, large

        var priceFont: Font {
            switch self {
            case .small: return DS.Font.bold(16)
            case .medium: return DS.Font.bold(24)
            case .large: return DS.Font.bold(32)
            }
        }

        var unitFont: Font {
            switch self {
            case .small: return DS.Font.micro
            case .medium: return DS.Font.caption
            case .large: return DS.Font.callout
            }
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
            Text("\(price)")
                .font(size.priceFont)
                .monospacedDigit()
                .foregroundStyle(useSemanticColor ? DS.Color.forCategory(category) : .primary)
            Text("öre")
                .font(size.unitFont)
                .foregroundStyle(DS.Color.secondary)
        }
    }
}

struct PriceIcon: View {
    let category: PriceCategory
    let size: CGFloat
    var useSemanticColor: Bool = true

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(useSemanticColor ? DS.Color.forCategory(category) : .primary)
    }
}

// MARK: - Accessible Price Badge

/// A badge that shows price level with both color AND icon/text for colorblind accessibility
struct PriceLevelBadge: View {
    let category: PriceCategory
    var style: Style = .full

    enum Style {
        case full      // Icon + label
        case compact   // Icon only
        case label     // Label only
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if style != .label {
                Image(systemName: category.accessibilityIcon)
                    .font(.system(size: 10, weight: .semibold))
            }
            if style != .compact {
                Text(category.label)
                    .font(DS.Font.semibold(10))
            }
        }
        .foregroundStyle(DS.Color.forCategory(category))
        .padding(.horizontal, style == .compact ? DS.Spacing.xs : DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(DS.Color.forCategory(category).opacity(0.15), in: Capsule())
    }
}

// MARK: - Canvas background

/// Calm field behind dashboard content. Replaces the old photo background so
/// materials and text keep contrast in light and dark mode.
struct AppCanvasBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark ? darkBase : lightBase,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: colorScheme == .dark ? darkWash : lightWash,
                center: .topLeading,
                startRadius: 24,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var lightBase: [Color] {
        [
            Color(red: 0.89, green: 0.92, blue: 0.95),
            Color(red: 0.94, green: 0.93, blue: 0.91)
        ]
    }

    private var darkBase: [Color] {
        [
            Color(red: 0.10, green: 0.12, blue: 0.16),
            Color(red: 0.07, green: 0.08, blue: 0.10)
        ]
    }

    private var lightWash: [Color] {
        [
            Color(red: 0.80, green: 0.87, blue: 0.93).opacity(0.55),
            .clear
        ]
    }

    private var darkWash: [Color] {
        [
            Color(red: 0.18, green: 0.22, blue: 0.30).opacity(0.40),
            .clear
        ]
    }
}

// MARK: - Palette-tinted cards

/// Semantic card tones mapped to existing `DS.Color` / asset-catalog tokens.
enum SpriceCardTone: Equatable {
    case `default`
    case accent
    case price
    case cost
    case history

    var paletteColor: Color {
        // One shared tint for every card so all tabs look the same.
        DS.Color.info
    }

    /// GlassEffect tint, the same for every tone.
    func glassTintOpacity(colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (_, .light): return 0.16
        case (_, .dark): return 0.20
        @unknown default:
            return 0.16
        }
    }

    /// Gradient overlay on top of material, kept below the glass tint.
    func overlayOpacity(colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (_, .light): return 0.10
        case (_, .dark): return 0.12
        @unknown default:
            return 0.10
        }
    }

    func reducedTransparencyOverlayOpacity(colorScheme: ColorScheme) -> Double {
        overlayOpacity(colorScheme: colorScheme) + 0.04
    }
}

/// Palette fill used by `spriceCard` and by Form `listRowBackground`.
struct SpriceCardBackground: View {
    var tone: SpriceCardTone = .default
    var cornerRadius: CGFloat = DS.Glass.cardRadius
    var isInteractive: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var paletteColor: Color { tone.paletteColor }

    /// Lifts body text onto the material so `.primary` and `DS.Color.secondary`
    /// stay at WCAG AA (4.5:1) against the tinted fill in both appearances.
    private var contrastFill: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.36)
            : Color.white.opacity(0.58)
    }

    private var opaqueBase: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private var glassTintOpacity: Double {
        tone.glassTintOpacity(colorScheme: colorScheme)
    }

    private var washOpacity: Double {
        reduceTransparency
            ? tone.reducedTransparencyOverlayOpacity(colorScheme: colorScheme)
            : tone.overlayOpacity(colorScheme: colorScheme)
    }

    private var glassStyle: Glass {
        let tinted: Glass = .regular.tint(paletteColor.opacity(glassTintOpacity))
        return isInteractive ? tinted.interactive() : tinted
    }

    private var paletteWash: LinearGradient {
        LinearGradient(
            colors: [
                paletteColor.opacity(washOpacity),
                paletteColor.opacity(washOpacity * 0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Group {
            if reduceTransparency {
                cardShape
                    .fill(opaqueBase)
                    .overlay {
                        cardShape.fill(paletteWash)
                    }
            } else {
                cardShape
                    .fill(.regularMaterial)
                    .overlay {
                        cardShape.fill(contrastFill)
                    }
                    .overlay {
                        cardShape.fill(paletteWash)
                    }
                    .glassEffect(glassStyle, in: cardShape)
            }
        }
    }
}

/// Palette-tinted material card. Native glass stays underneath; only the
/// background is clipped so chart callouts can overflow.
struct SpriceCardModifier: ViewModifier {
    let tone: SpriceCardTone
    let cornerRadius: CGFloat
    let isInteractive: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                SpriceCardBackground(
                    tone: tone,
                    cornerRadius: cornerRadius,
                    isInteractive: isInteractive
                )
                .clipShape(cardShape)
            }
            .overlay {
                cardShape.strokeBorder(strokeColor, lineWidth: 0.5)
            }
            .containerShape(cardShape)
    }

    private var strokeColor: Color {
        tone.paletteColor.opacity(colorScheme == .dark ? 0.28 : 0.16)
    }
}

extension View {
    /// Palette-tinted material card used by iOS, macOS and widgets.
    func spriceCard(
        tone: SpriceCardTone = .default,
        cornerRadius: CGFloat = DS.Glass.cardRadius,
        interactive: Bool = false
    ) -> some View {
        modifier(SpriceCardModifier(tone: tone, cornerRadius: cornerRadius, isInteractive: interactive))
    }

    /// Forwards to `spriceCard(tone: .default)` so older call sites keep compiling.
    func glassCard(cornerRadius: CGFloat = DS.Glass.cardRadius, interactive: Bool = false) -> some View {
        spriceCard(tone: .default, cornerRadius: cornerRadius, interactive: interactive)
    }

    /// Same palette fill as `spriceCard`, for grouped Form rows. Corner radius is
    /// 0 so the Form can clip the section as one card.
    func spriceListRowBackground(tone: SpriceCardTone = .default) -> some View {
        listRowBackground(
            SpriceCardBackground(tone: tone, cornerRadius: 0)
        )
    }
}

// MARK: - Trend Indicator

/// Shows price trend direction with accessible icon
struct TrendIndicator: View {
    let current: Double
    let next: Double

    private var change: Double { next - current }
    private var percentChange: Double {
        guard current > 0 else { return 0 }
        return (change / current) * 100
    }

    private var icon: String {
        if change > 0 { return "arrow.up.right" }
        if change < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var color: Color {
        if change > 0 { return DS.Color.danger }
        if change < 0 { return DS.Color.success }
        return DS.Color.secondary
    }

    private var accessibilityLabel: String {
        if change > 0 { return "Ökar" }
        if change < 0 { return "Minskar" }
        return "Stabilt"
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(color)
        .accessibilityLabel(accessibilityLabel)
    }
}
