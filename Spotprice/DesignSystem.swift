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
            .custom("Avenir", size: size)
        }

        static func medium(_ size: CGFloat) -> SwiftUI.Font {
            .custom("Avenir", size: size).weight(.medium)
        }

        static func semibold(_ size: CGFloat) -> SwiftUI.Font {
            .custom("Avenir", size: size).weight(.semibold)
        }

        static func bold(_ size: CGFloat) -> SwiftUI.Font {
            .custom("Avenir", size: size).weight(.bold)
        }

        // Preset sizes
        static let largeTitle = bold(32)
        static let title = bold(20)
        static let headline = semibold(16)
        static let body = regular(14)
        static let callout = medium(13)
        static let caption = medium(11)
        static let micro = medium(10)
    }

    // MARK: - Semantic Colors

    enum Color {
        static let success = SwiftUI.Color.green
        static let warning = SwiftUI.Color.orange
        static let error = SwiftUI.Color.red

        static func forCategory(_ category: PriceCategory) -> SwiftUI.Color {
            switch category {
            case .low: return success
            case .medium: return warning
            case .high: return error
            }
        }

        /// Returns a color based on where the price falls in the day's range
        /// - Parameters:
        ///   - price: Current price
        ///   - min: Day's minimum price
        ///   - max: Day's maximum price
        /// - Returns: Green for low, yellow/orange for medium, red for high
        static func forPrice(_ price: Double, min: Double, max: Double) -> SwiftUI.Color {
            let range = max - min
            guard range > 0 else { return warning }

            let normalized = (price - min) / range

            if normalized <= 0.33 {
                return success
            } else if normalized <= 0.66 {
                return warning
            } else {
                return error
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
