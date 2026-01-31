//
//  GlassEffectContainer.swift
//  Spotprice
//

import SwiftUI

struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(spacing: spacing) {
            content()
        }
    }
}
