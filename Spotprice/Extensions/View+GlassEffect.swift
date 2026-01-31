//
//  View+GlassEffect.swift
//  Spotprice
//

import SwiftUI

extension View {
    func glassEffect(_ material: Material, in shape: some InsettableShape) -> some View {
        self.background(material, in: shape)
    }

    func glassEffect(_ material: Material, in shape: AnyShape) -> some View {
        self.background(material)
            .clipShape(shape)
    }
}

extension Material {
    static let regular = Material.regularMaterial
}

extension AnyShape {
    static let circle = AnyShape(Circle())
    static let capsule = AnyShape(Capsule())
}
