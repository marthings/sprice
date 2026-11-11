//
//  DesignSystem.swift
//  Spotprice
//
//  Shared design tokens for app and widget
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
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

    nonisolated static func shortClock(_ date: Date) -> String {
        let style = Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: swedishLocale,
            calendar: energyCalendar,
            timeZone: swedishTimeZone
        ).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        return date.formatted(style)
    }

    nonisolated static func relativeStamp(_ date: Date, now: Date = Date()) -> String {
        if energyCalendar.isDate(date, inSameDayAs: now) {
            return shortClock(date)
        }
        if let yesterday = energyCalendar.date(byAdding: .day, value: -1, to: energyCalendar.startOfDay(for: now)),
           energyCalendar.isDate(date, inSameDayAs: yesterday) {
            return "i går \(shortClock(date))"
        }
        let dayStyle = Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: swedishLocale,
            calendar: energyCalendar,
            timeZone: swedishTimeZone
        ).day().month(.abbreviated)
        return "\(date.formatted(dayStyle)) \(shortClock(date))"
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

    /// Full weekday and month, safe at the end of a sentence (no trailing period).
    nonisolated static func sentenceWeekdayDayMonth(_ date: Date) -> String {
        let style = Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: swedishLocale,
            calendar: energyCalendar,
            timeZone: swedishTimeZone
        ).weekday(.wide).day().month(.wide)
        return withoutTrailingPeriod(date.formatted(style))
    }

    /// Full month and clock hour, safe at the end of a sentence (no trailing period).
    nonisolated static func sentenceDayMonthAndHour(_ date: Date) -> String {
        let style = Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: swedishLocale,
            calendar: energyCalendar,
            timeZone: swedishTimeZone
        )
        let day = date.formatted(style.day().month(.wide))
        let hour = date.formatted(style.hour(.defaultDigits(amPM: .omitted)))
        return withoutTrailingPeriod("\(day) klockan \(hour)")
    }

    /// Swedish abbreviated months often end with a period ("8 nov.").
    /// Strip it when the value is placed at the end of a sentence that already has one.
    nonisolated static func withoutTrailingPeriod(_ text: String) -> String {
        var result = text
        while result.hasSuffix(".") {
            result.removeLast()
        }
        return result
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
        /// Apple's text styles at the standard text size. Each size in the app maps to the
        /// closest one, so Dynamic Type grows and shrinks everything in Apple's own steps.
        private static let textStyleSizes: [(size: CGFloat, style: SwiftUI.Font.TextStyle)] = [
            (11, .caption2), (12, .caption), (13, .footnote), (15, .subheadline), (16, .callout),
            (17, .body), (20, .title3), (22, .title2), (28, .title), (34, .largeTitle)
        ]

        /// The text style whose standard size is closest to `size`. Ties go to the larger one.
        static func textStyle(forSize size: CGFloat) -> SwiftUI.Font.TextStyle {
            var best = textStyleSizes[0]
            for candidate in textStyleSizes where abs(candidate.size - size) <= abs(best.size - size) {
                best = candidate
            }
            return best.style
        }

        /// Smallest size used for text that carries information (13 pt).
        static let minimumInformationSize: CGFloat = 13

        private static func informative(_ size: CGFloat) -> CGFloat {
            max(size, minimumInformationSize)
        }

        /// Manrope, under the SIL Open Font License 1.1 (free for commercial apps).
        /// The files and OFL.txt are in Shared/DesignSystem/Fonts. They are registered
        /// through UIAppFonts (iOS) and ATSApplicationFontsPath (macOS) in each Info.plist.
        static let fontNames = [
            "Manrope-Regular", "Manrope-Medium", "Manrope-SemiBold", "Manrope-Bold", "Manrope-ExtraBold"
        ]

        /// The Manrope file for a weight. Manrope draws lighter than the old PP Object Sans,
        /// so headings, amounts and units go one step heavier: semibold uses Manrope Bold and
        /// bold uses Manrope ExtraBold. Body text (regular and medium) keeps its own weight.
        static func fontName(for weight: SwiftUI.Font.Weight) -> String {
            switch weight {
            case .medium: return "Manrope-Medium"
            case .semibold: return "Manrope-Bold"
            case .bold, .heavy, .black: return "Manrope-ExtraBold"
            default: return "Manrope-Regular"
            }
        }

        /// Font names that did not load. Empty when everything is in place.
        static func missingFonts() -> [String] {
            #if os(macOS)
            return fontNames.filter { NSFont(name: $0, size: 12) == nil }
            #else
            return fontNames.filter { UIFont(name: $0, size: 12) == nil }
            #endif
        }

        /// iOS: Manrope at the given size, scaled with the closest text style, so it follows Dynamic Type.
        /// macOS: exact sizes, since macOS has no Dynamic Type.
        private static func system(_ size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            #if os(macOS)
            return .custom(fontName(for: weight), fixedSize: size)
            #else
            return .custom(fontName(for: weight), size: size, relativeTo: textStyle(forSize: size))
            #endif
        }

        static func regular(_ size: CGFloat) -> SwiftUI.Font {
            system(informative(size), weight: .regular)
        }

        static func medium(_ size: CGFloat) -> SwiftUI.Font {
            system(informative(size), weight: .medium)
        }

        static func semibold(_ size: CGFloat) -> SwiftUI.Font {
            system(informative(size), weight: .semibold)
        }

        static func bold(_ size: CGFloat) -> SwiftUI.Font {
            system(informative(size), weight: .bold)
        }

        /// An exact size that does not follow a text style. Use it for big numbers that
        /// the caller scales itself with `@ScaledMetric(relativeTo:)`, and for widgets
        /// and menu bar text, where the size is set by the layout.
        static func fixed(_ size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .custom(fontName(for: weight), fixedSize: size)
        }

        /// Decoration only (never for text people need to read).
        static func decorative(_ size: CGFloat) -> SwiftUI.Font {
            system(size, weight: .regular)
        }

        // Preset sizes
        static let largeTitle = bold(32)
        static let title = bold(20)
        static let headline = bold(17)
        static let body = regular(15)
        static let callout = medium(14)
        static let caption = medium(13)
        /// Small notes and axis labels. 13 pt, the smallest size for readable text.
        static let footnote = medium(13)
        /// Units next to an amount (kr, kWh, kr/kWh). Heavier than notes so they don't look weak next to the number.
        static let unit = bold(13)
        /// Units next to a big hero amount.
        static let unitLarge = bold(15)

        #if os(iOS)
        /// Navigation titles can't take a SwiftUI `Font`, so UIKit chrome uses this.
        static func configureNavigationBarAppearance() {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: uiBold(size: 17, textStyle: .headline),
                .foregroundColor: UIColor.label
            ]
            let largeTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: uiBold(size: 34, textStyle: .largeTitle),
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

        private static func uiBold(size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
            let base = UIFont(name: fontName(for: .bold), size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .bold)
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
        /// Palette orange (`WarningColor`). App tint for toggles, links and selected tabs.
        static let accent = warning

        // Text variants. The fill colors above are tuned for shapes and fills and
        // are too light to read as text on the cards (about 2.3 to 3.5 to 1). These
        // reach at least 4.5 to 1 against the card in light and dark mode, and get
        // another step darker (light) or lighter (dark) with Increase Contrast.
        static let warningText = adaptive(light: 0x8C4207, dark: 0xF5A35C)
        static let infoText = adaptive(light: 0x005580, dark: 0x5CCBEF)
        static let successText = adaptive(light: 0x245810, dark: 0x86CC5A)
        static let dangerText = adaptive(light: 0xA8161A, dark: 0xFF8A80)
        /// Orange for text and links. The brighter `accent` stays for fills and tint.
        static let accentText = warningText

        static let secondary = SwiftUI.Color.primary.opacity(0.72)
        static let outline = SwiftUI.Color.primary.opacity(0.28)

        static func forCategory(_ category: PriceCategory) -> SwiftUI.Color {
            switch category {
            case .low: return success
            case .medium: return warning
            case .high: return danger
            }
        }

        /// Same mapping as `forCategory`, for text.
        static func textForCategory(_ category: PriceCategory) -> SwiftUI.Color {
            switch category {
            case .low: return successText
            case .medium: return warningText
            case .high: return dangerText
            }
        }

        nonisolated private static func rgb(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
        }

        /// Moves a color a third of the way toward black (light) or white (dark).
        nonisolated private static func stronger(_ value: (CGFloat, CGFloat, CGFloat), isDark: Bool) -> (CGFloat, CGFloat, CGFloat) {
            let target: CGFloat = isDark ? 1 : 0
            let amount: CGFloat = 0.33
            return (
                value.0 + (target - value.0) * amount,
                value.1 + (target - value.1) * amount,
                value.2 + (target - value.2) * amount
            )
        }

        private static func adaptive(light: UInt32, dark: UInt32) -> SwiftUI.Color {
            #if os(iOS)
            return SwiftUI.Color(uiColor: UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                var value = rgb(isDark ? dark : light)
                if traits.accessibilityContrast == .high { value = stronger(value, isDark: isDark) }
                return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
            })
            #else
            return SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                var value = rgb(isDark ? dark : light)
                if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast { value = stronger(value, isDark: isDark) }
                return NSColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
            })
            #endif
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
        /// Inner padding of content cards, on all sides.
        static let card: CGFloat = 20
        /// Distance from a card title (and info icon) down to the content.
        static let cardContent: CGFloat = 12
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

    // MARK: - Motion

    /// Considered, not flashy. `.smooth` for numbers and reveals, `.snappy`
    /// for charts and press. Reduce Motion replaces springs with a short fade.
    enum Motion {
        static let numbers: Animation = .smooth(duration: 0.45)
        static let reveal: Animation = .smooth(duration: 0.35)
        static let chart: Animation = .snappy(duration: 0.5)
        static let press: Animation = .snappy(duration: 0.2)
        static let reduced: Animation = .easeInOut(duration: 0.2)

        static func curve(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? reduced : animation
        }

        static func revealTransition(reduceMotion: Bool) -> AnyTransition {
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity
                )
        }
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
        static let infoIcon: CGFloat = 16
        static let infoHit: CGFloat = 44
        static var infoHitInset: CGFloat { (infoHit - infoIcon) / 2 }
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

    /// Same tones as `displayColor`, dark enough to read as text.
    var displayTextColor: Color {
        switch self {
        case .priceOnly:
            return DS.Color.secondary
        case .estimatedCost:
            return DS.Color.warningText
        case .partialConsumption:
            return DS.Color.infoText
        case .measuredConsumption:
            return DS.Color.successText
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
                    .font(DS.Font.footnote)
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
        .padding(DS.Spacing.card)
        .spriceCard(tone: .default, interactive: interactive)
    }
}

struct FetchNoticeBanner: View {
    let notice: FetchNotice

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: notice.icon)
                .font(.system(size: DS.Size.iconSmall, weight: .semibold))
                .foregroundStyle(toneColor)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(DS.Font.callout)
                    .foregroundStyle(notice.tone == .info ? DS.Color.secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = notice.detail, !detail.isEmpty {
                    Text(detail)
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Glass.smallRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Glass.smallRadius, style: .continuous)
                        .fill(toneColor.opacity(notice.tone == .info ? 0.06 : 0.12))
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notice.accessibilityText)
    }

    private var toneColor: Color {
        switch notice.tone {
        case .info:
            return DS.Color.secondary
        case .warning:
            return DS.Color.warning
        case .error:
            return DS.Color.danger
        }
    }
}

struct FetchNoticeStack: View {
    let notices: [FetchNotice]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleNotices: [FetchNotice]

    init(notices: [FetchNotice]) {
        self.notices = notices
        _visibleNotices = State(initialValue: notices)
    }

    var body: some View {
        Group {
            if !visibleNotices.isEmpty {
                VStack(alignment: .center, spacing: DS.Spacing.xs) {
                    ForEach(Self.ordered(visibleNotices)) { notice in
                        FetchNoticeFooterLine(notice: notice)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.md)
                .accessibilityElement(children: .contain)
                .transition(DS.Motion.revealTransition(reduceMotion: reduceMotion))
            }
        }
        .onChange(of: notices.map(\.id)) { _, _ in
            withAnimation(DS.Motion.curve(DS.Motion.reveal, reduceMotion: reduceMotion)) {
                visibleNotices = notices
            }
        }
    }

    private static func ordered(_ notices: [FetchNotice]) -> [FetchNotice] {
        notices.enumerated().sorted { lhs, rhs in
            if lhs.element.isActionable != rhs.element.isActionable {
                return lhs.element.isActionable && !rhs.element.isActionable
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}

private struct FetchNoticeFooterLine: View {
    let notice: FetchNotice
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if notice.isActionable {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Image(systemName: notice.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(notice.accessibilityText)
                        .font(DS.Font.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(DS.Color.warningText)
            } else {
                Text(notice.accessibilityText)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .shadow(color: contrastShadow, radius: 5, x: 0, y: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notice.accessibilityText)
    }

    private var contrastShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.75)
            : Color.white.opacity(0.85)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var showsChevron: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSmall, weight: .semibold))
                .foregroundStyle(DS.Color.accent)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(DS.Font.footnote)
                        .foregroundStyle(DS.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondary)
                    .accessibilityHidden(true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.map { "\(title) \($0)" } ?? title)
        .transition(DS.Motion.revealTransition(reduceMotion: reduceMotion))
    }
}

struct CardInsight: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    var detail: String? = nil
    var showsChevron: Bool = false
}

struct HistoryCoverageBadge: View {
    let coverage: HistoricalEnergyDataCoverage
    var horizontalPadding: CGFloat = DS.Spacing.sm

    var body: some View {
        Text(coverage.displayTitle)
            .font(DS.Font.footnote)
            .foregroundStyle(coverage.displayTextColor)
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
        .font(DS.Font.footnote)
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
    var unitFont: Font = DS.Font.unit
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
                .font(DS.Font.footnote)
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
                    .font(DS.Font.footnote)
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
            case .small: return DS.Font.unit
            case .medium: return DS.Font.unit
            case .large: return DS.Font.unitLarge
            }
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
            Text("\(price)")
                .font(size.priceFont)
                .monospacedDigit()
                .foregroundStyle(useSemanticColor ? DS.Color.textForCategory(category) : .primary)
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
                    .font(DS.Font.semibold(13))
            }
            if style != .compact {
                Text(category.label)
                    .font(DS.Font.semibold(13))
            }
        }
        .foregroundStyle(DS.Color.textForCategory(category))
        .padding(.horizontal, style == .compact ? DS.Spacing.xs : DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(DS.Color.forCategory(category).opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prisnivå \(category.label)")
    }
}

// MARK: - Canvas background

/// Full-bleed landscape reused by every screen (light/dark asset). Completely still.
/// Depth comes from three fixed layers on top of the watercolor: a deeper sky towards the
/// top, a soft warm glow at the horizon, and a faint vignette at the edges. Cards sit
/// above all of it and keep their own material, so text reads the same in light and dark.
/// Layout-neutral: the image lives in an overlay so `scaledToFill` never
/// expands the parent (which would wipe out horizontal padding).
struct AppCanvasBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        base
            .overlay(alignment: .bottom) {
                Image("LandscapeBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            }
            .overlay { deeperSky }
            .overlay { horizonGlow }
            .overlay { vignette }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var isDark: Bool { colorScheme == .dark }

    private var base: Color {
        isDark
            ? Color(red: 0.045, green: 0.05, blue: 0.065)
            : Color(red: 0.78, green: 0.86, blue: 0.94)
    }

    /// The sky gets a little deeper towards the top, fading out by the middle of the screen.
    private var deeperSky: some View {
        let top = isDark ? Color(red: 0.10, green: 0.08, blue: 0.30) : Color(red: 0.55, green: 0.69, blue: 0.88)
        return LinearGradient(
            stops: [
                .init(color: top.opacity(isDark ? 0.55 : 0.42), location: 0),
                .init(color: top.opacity(isDark ? 0.18 : 0.12), location: 0.35),
                .init(color: top.opacity(0), location: 0.62)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A soft glow where the sun sits behind the ridge.
    private var horizonGlow: some View {
        let warm = isDark ? Color(red: 0.80, green: 0.36, blue: 0.12) : Color(red: 1.00, green: 0.70, blue: 0.45)
        return GeometryReader { geometry in
            RadialGradient(
                colors: [warm.opacity(isDark ? 0.34 : 0.32), warm.opacity(isDark ? 0.10 : 0.10), warm.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.82),
                startRadius: 0,
                endRadius: max(geometry.size.width, geometry.size.height * 0.5) * 0.9
            )
        }
    }

    /// Darkens the corners a little, so the middle of the screen feels closer.
    private var vignette: some View {
        GeometryReader { geometry in
            RadialGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(isDark ? 0.34 : 0.10)],
                center: .center,
                startRadius: min(geometry.size.width, geometry.size.height) * 0.45,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.78
            )
        }
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

    /// Gradient overlay on top of material.
    func overlayOpacity(colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (_, .light): return 0.14
        case (_, .dark): return 0.16
        @unknown default:
            return 0.14
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
    /// Flat fill for grouped Form rows: no per-row gradient, so rows share one wash.
    var isListRow: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var paletteColor: Color { tone.paletteColor }

    /// Very faint lift *under* the ultra-thin material so `.primary` stays at
    /// WCAG AA (4.5:1) against the landscape in both appearances, without
    /// making the card look solid.
    private var contrastFill: Color {
        let increased = contrast == .increased
        return colorScheme == .dark
            ? Color.black.opacity(increased ? 0.5 : 0.32)
            : Color.white.opacity(increased ? 0.62 : 0.40)
    }

    /// With Increase Contrast on, cards get a clear edge so they stand out from the landscape.
    private var increasedContrastEdge: some View {
        cardShape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.5 : 0), lineWidth: 1)
    }

    private var opaqueBase: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private var washOpacity: Double {
        reduceTransparency
            ? tone.reducedTransparencyOverlayOpacity(colorScheme: colorScheme)
            : tone.overlayOpacity(colorScheme: colorScheme)
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

    private var flatPaletteFill: Color {
        paletteColor.opacity(washOpacity)
    }

    var body: some View {
        Group {
            if isListRow {
                listRowBackground
            } else if reduceTransparency {
                cardShape
                    .fill(opaqueBase)
                    .overlay {
                        cardShape.fill(paletteWash)
                    }
                    .overlay { increasedContrastEdge }
            } else {
                cardShape
                    .fill(contrastFill)
                    .overlay {
                        cardShape.fill(.ultraThinMaterial)
                    }
                    .overlay {
                        cardShape.fill(paletteWash)
                    }
                    .overlay { increasedContrastEdge }
            }
        }
    }

    @ViewBuilder
    private var listRowBackground: some View {
        if reduceTransparency {
            cardShape
                .fill(opaqueBase)
                .overlay {
                    cardShape.fill(flatPaletteFill)
                }
        } else {
            cardShape
                .fill(contrastFill)
                .overlay {
                    cardShape.fill(.ultraThinMaterial)
                }
                .overlay {
                    cardShape.fill(flatPaletteFill)
                }
        }
    }
}

/// Palette-tinted material card. Only the background is clipped so chart
/// callouts can overflow.
struct SpriceCardModifier: ViewModifier {
    let tone: SpriceCardTone
    let cornerRadius: CGFloat

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                SpriceCardBackground(
                    tone: tone,
                    cornerRadius: cornerRadius
                )
                .clipShape(cardShape)
            }
            .containerShape(cardShape)
    }
}

/// Discrete press for tappable cards that used to use interactive glass.
struct SpriceCardPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.98
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(DS.Motion.curve(DS.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

private struct SpriceNumericTextModifier: ViewModifier {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .numericText(value: value))
            .animation(DS.Motion.curve(DS.Motion.numbers, reduceMotion: reduceMotion), value: value)
    }
}

private struct SpriceValueAnimationModifier: ViewModifier {
    let value: [AnyHashable]
    let animation: Animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var token: [AnyHashable] { [hasAppeared] + value }

    func body(content: Content) -> some View {
        content
            .animation(DS.Motion.curve(animation, reduceMotion: reduceMotion), value: token)
            .onAppear { hasAppeared = true }
    }
}

extension View {
    /// Palette-tinted material card used by iOS, macOS and widgets.
    func spriceCard(
        tone: SpriceCardTone = .default,
        cornerRadius: CGFloat = DS.Glass.cardRadius,
        interactive: Bool = false
    ) -> some View {
        let _ = interactive
        return modifier(SpriceCardModifier(tone: tone, cornerRadius: cornerRadius))
    }

    /// Forwards to `spriceCard(tone: .default)` so older call sites keep compiling.
    func glassCard(cornerRadius: CGFloat = DS.Glass.cardRadius, interactive: Bool = false) -> some View {
        spriceCard(tone: .default, cornerRadius: cornerRadius, interactive: interactive)
    }

    /// Same palette fill as `spriceCard`, for grouped Form rows. Corner radius is
    /// 0 so the Form can clip the section as one card. Flat: no glass edge.
    func spriceListRowBackground(tone: SpriceCardTone = .default) -> some View {
        listRowBackground(
            SpriceCardBackground(tone: tone, cornerRadius: 0, isListRow: true)
        )
    }

    func spriceSettingsHeaderStyle() -> some View {
        font(DS.Font.caption)
            .foregroundStyle(DS.Color.secondary)
            .textCase(.uppercase)
    }

    func spriceSettingsFooterStyle() -> some View {
        font(DS.Font.footnote)
            .foregroundStyle(DS.Color.secondary)
    }

    /// Ticks digits in place when `value` changes. Honors Reduce Motion.
    func spriceNumericText(_ value: Double) -> some View {
        modifier(SpriceNumericTextModifier(value: value))
    }

    /// Spring (or a short fade if Reduce Motion is on) when chart data or selection changes.
    func spriceChartMotion(_ values: AnyHashable...) -> some View {
        modifier(SpriceValueAnimationModifier(value: values, animation: DS.Motion.chart))
    }

    /// Reveal or hide footers and insight groups.
    func spriceRevealMotion(_ values: AnyHashable...) -> some View {
        modifier(SpriceValueAnimationModifier(value: values, animation: DS.Motion.reveal))
    }

#if os(iOS)
    /// Insets scroll content to the safe area (including the floating tab bar)
    /// plus `DS.Spacing.lg` of air at the bottom, and the usual space below a
    /// navigation title at the top. Replaces a hard-coded bottom padding so
    /// the last views stay visible above the tab bar on every device.
    func spriceScrollContentMargins() -> some View {
        contentMargins(
            .all,
            EdgeInsets(
                top: DS.Spacing.titleToContent,
                leading: 0,
                bottom: DS.Spacing.lg,
                trailing: 0
            ),
            for: .scrollContent
        )
    }
#endif
}

/// One line above a chart that says what the chart shows and in which unit.
/// It replaces the axis titles, which stay hidden to keep the plot calm.
struct ChartCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(DS.Font.footnote)
            .foregroundStyle(DS.Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Menu picker whose trailing value is a `DS.Font` `Text`, for grouped Forms.
struct SpriceSettingsMenuPicker<Selection: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Selection
    let valueText: String
    var monospacedValue: Bool = false
    let options: Options

    init(
        title: String,
        selection: Binding<Selection>,
        valueText: String,
        monospacedValue: Bool = false,
        @ViewBuilder options: () -> Options
    ) {
        self.title = title
        self._selection = selection
        self.valueText = valueText
        self.monospacedValue = monospacedValue
        self.options = options()
    }

    var body: some View {
        LabeledContent(title) {
            Menu {
                Picker(title, selection: $selection) {
                    options
                }
            } label: {
                Text(valueText)
                    .font(monospacedValue ? DS.Font.body.monospacedDigit() : DS.Font.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityLabel(title)
            .accessibilityValue(valueText)
        }
        .spriceListRowBackground()
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


// MARK: - Section info (title, button and sheet)

struct SectionInfoLegendItem: Identifiable {
    let id: String
    let color: Color
    let label: String

    init(id: String? = nil, color: Color, label: String) {
        self.id = id ?? label
        self.color = color
        self.label = label
    }
}

/// Title with a discrete info button that opens a fuller explanation.
struct SectionInfoHeader: View {
    let title: String
    var titleFont: Font = DS.Font.headline
    var titleColor: Color = .primary
    var accessibilityName: String? = nil
    let paragraphs: [String]
    var legend: [SectionInfoLegendItem] = []
    /// Small status chip next to the title, such as "Pågår". Hidden when nil.
    var badge: String? = nil
    var badgeAccessibilityLabel: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: badge == nil ? .infinity : nil, alignment: .leading)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)

            if let badge {
                Text(badge)
                    .font(DS.Font.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Color.warning.opacity(0.18), in: Capsule())
                    .padding(.leading, DS.Spacing.sm)
                    .accessibilityLabel(badgeAccessibilityLabel ?? badge)

                Spacer(minLength: DS.Spacing.sm)
            }

            SectionInfoButton(
                title: accessibilityName ?? title,
                paragraphs: paragraphs,
                legend: legend
            )
        }
        .accessibilityElement(children: .contain)
    }
}

struct SectionInfoButton: View {
    let title: String
    let paragraphs: [String]
    var legend: [SectionInfoLegendItem] = []

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: DS.Size.infoIcon, weight: .regular))
                .foregroundStyle(DS.Color.secondary)
                .frame(width: DS.Size.infoHit, height: DS.Size.infoHit, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(SpriceCardPressButtonStyle(scale: 0.9))
        .padding(.vertical, -DS.Size.infoHitInset)
        .padding(.trailing, -DS.Size.infoHitInset)
        .accessibilityLabel("Mer om \(title)")
        .accessibilityHint("Visar en förklaring")
        .accessibilityAddTraits(.isButton)
#if os(macOS)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SectionInfoSheet(title: title, paragraphs: paragraphs, legend: legend)
                .frame(minWidth: 280, idealWidth: 320, minHeight: 200, idealHeight: 360)
        }
#else
        .sheet(isPresented: $isPresented) {
            SectionInfoSheet(title: title, paragraphs: paragraphs, legend: legend)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
#endif
    }
}

struct SectionInfoSheet: View {
    let title: String
    let paragraphs: [String]
    var legend: [SectionInfoLegendItem] = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(DS.Font.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !legend.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            ForEach(legend) { item in
                                HStack(spacing: DS.Spacing.sm) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 10, height: 10)
                                        .accessibilityHidden(true)
                                    Text(item.label)
                                        .font(DS.Font.callout)
                                        .foregroundStyle(.primary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(item.label)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
#endif
        }
    }
}
