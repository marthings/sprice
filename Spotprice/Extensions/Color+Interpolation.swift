//
//  Color+Interpolation.swift
//  Spotprice
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

extension Color {
    func interpolated(to color: Color, by factor: Double) -> Color {
        let clampedFactor = max(0, min(1, factor))

        let fromComponents = self.rgbComponents()
        let toComponents = color.rgbComponents()

        let red = fromComponents.red + (toComponents.red - fromComponents.red) * clampedFactor
        let green = fromComponents.green + (toComponents.green - fromComponents.green) * clampedFactor
        let blue = fromComponents.blue + (toComponents.blue - fromComponents.blue) * clampedFactor

        return Color(red: red, green: green, blue: blue)
    }

    private func rgbComponents() -> (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        let convertedColor = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return (Double(convertedColor.redComponent), Double(convertedColor.greenComponent), Double(convertedColor.blueComponent))
        #else
        return (0.5, 0.5, 0.5)
        #endif
    }
}
