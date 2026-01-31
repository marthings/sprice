//
//  RemoveWindowBorder.swift
//  Spotprice
//

import SwiftUI
import AppKit

struct RemoveWindowBorder: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.remove(.titled)
                window.styleMask.insert(.borderless)
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = true
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
