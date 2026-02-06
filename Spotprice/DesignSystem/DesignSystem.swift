//
//  DesignSystem.swift
//  Spotprice
//
//  Shared design tokens for app and widget
//

import SwiftUI

// MARK: - Design System

enum DS {

    // MARK: - Typography

    enum Font {
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
    }

    // MARK: - Semantic Colors

    enum Color {
        // Semantic colors from assets (auto light/dark)
        static let brand = SwiftUI.Color("BrandColor")
        static let success = SwiftUI.Color("SuccessColor")
        static let info = SwiftUI.Color("InfoColor")
        static let warning = SwiftUI.Color("WarningColor")
        static let danger = SwiftUI.Color("DangerColor")

        static let outline = SwiftUI.Color.secondary

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
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999
    }

    // MARK: - Glass Effects (macOS 26+)

    enum Glass {
        /// Standard corner radius for glass cards
        static let cardRadius: CGFloat = Radius.lg
        /// Corner radius for small glass elements
        static let smallRadius: CGFloat = Radius.md
    }

    // MARK: - Component Sizes

    enum Size {
        // Menu Bar
        static let menuBarWidth: CGFloat = 360
        static let menuBarHeight: CGFloat = 720

        // Charts
        static let chartHeightMenuBar: CGFloat = 180
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
}

// MARK: - Reusable Price Components

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
                .foregroundStyle(.secondary)
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

// MARK: - Glass Card Modifier

/// A modifier that applies glass effect on macOS 26+ with ultraThinMaterial fallback
struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if isInteractive {
                content
                    .glassEffect(.clear.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Applies a glass card style with automatic fallback for older macOS versions
    func glassCard(cornerRadius: CGFloat = DS.Glass.cardRadius, interactive: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, isInteractive: interactive))
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
        return .secondary
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
