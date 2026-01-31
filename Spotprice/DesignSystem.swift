//
//  DesignSystem.swift
//  Spotprice
//
//  Shared design system for app and widget
//

import SwiftUI

// MARK: - Typography

enum DS {
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

    // MARK: - Colors

    enum Color {
        static let primary = SwiftUI.Color.primary
        static let secondary = SwiftUI.Color.secondary

        static let success = SwiftUI.Color.green
        static let warning = SwiftUI.Color.orange
        static let error = SwiftUI.Color.red

        static let accent = SwiftUI.Color.blue

        // Price category colors
        static let priceLow = success
        static let priceMedium = warning
        static let priceHigh = error

        static func forCategory(_ category: PriceCategory) -> SwiftUI.Color {
            switch category {
            case .low: return priceLow
            case .medium: return priceMedium
            case .high: return priceHigh
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
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let full: CGFloat = 999
    }
}

// MARK: - View Extensions

extension View {
    func dsFont(_ font: Font) -> some View {
        self.font(font)
    }

    func dsCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(DS.Radius.lg)
    }

    func dsPill() -> some View {
        self
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(.ultraThinMaterial)
            .cornerRadius(DS.Radius.full)
    }
}

// MARK: - Price Display Component

struct PriceDisplay: View {
    let price: Int
    let category: PriceCategory
    let size: Size

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
                .foregroundStyle(DS.Color.forCategory(category))
            Text("öre")
                .font(size.unitFont)
                .foregroundStyle(DS.Color.secondary)
        }
    }
}

// MARK: - Icon with Badge

struct PriceIcon: View {
    let category: PriceCategory
    let size: CGFloat

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(DS.Color.forCategory(category).gradient)
    }
}
