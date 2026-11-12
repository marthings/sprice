//
//  WidgetDayChart.swift
//  Spotprice
//

import SwiftUI
import WidgetKit

struct WidgetDayChart: View {
    let costs: [Double]
    let currentIndex: Int?

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let minCost = costs.min() ?? 0
            let maxCost = costs.max() ?? 0
            let safeRange = max(maxCost - minCost, 1)

            ZStack {
                areaPath(width: width, height: height, minCost: minCost, safeRange: safeRange)
                    .fill(areaGradient)

                linePath(width: width, height: height, minCost: minCost, safeRange: safeRange)
                    .stroke(
                        lineGradient(minCost: minCost, maxCost: maxCost),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )

                if let currentIndex,
                   costs.count > 1,
                   costs.indices.contains(currentIndex) {
                    currentTimeIndicator(
                        width: width,
                        height: height,
                        index: currentIndex,
                        minCost: minCost,
                        maxCost: maxCost,
                        safeRange: safeRange
                    )
                }
            }
        }
    }

    private var areaGradient: LinearGradient {
        switch renderingMode {
        case .accented:
            return LinearGradient(
                colors: [.primary.opacity(0.3), .primary.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            return LinearGradient(
                colors: [DS.Color.accent.opacity(0.4), DS.Color.accent.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func lineGradient(minCost: Double, maxCost: Double) -> LinearGradient {
        switch renderingMode {
        case .accented:
            return LinearGradient(colors: [.primary], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(
                colors: costs.map { DS.Color.forPrice($0, min: minCost, max: maxCost) },
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func yPosition(for cost: Double, height: CGFloat, minCost: Double, safeRange: Double) -> CGFloat {
        let normalized = (cost - minCost) / safeRange
        return height - (normalized * height * 0.85) - (height * 0.075)
    }

    private func areaPath(width: CGFloat, height: CGFloat, minCost: Double, safeRange: Double) -> Path {
        Path { path in
            guard costs.count > 1 else { return }
            let stepX = width / CGFloat(costs.count - 1)

            path.move(to: CGPoint(x: 0, y: height))
            for (index, cost) in costs.enumerated() {
                path.addLine(to: CGPoint(
                    x: CGFloat(index) * stepX,
                    y: yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange)
                ))
            }
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }

    private func linePath(width: CGFloat, height: CGFloat, minCost: Double, safeRange: Double) -> Path {
        Path { path in
            guard costs.count > 1 else { return }
            let stepX = width / CGFloat(costs.count - 1)

            for (index, cost) in costs.enumerated() {
                let point = CGPoint(
                    x: CGFloat(index) * stepX,
                    y: yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange)
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(
        width: CGFloat,
        height: CGFloat,
        index: Int,
        minCost: Double,
        maxCost: Double,
        safeRange: Double
    ) -> some View {
        let stepX = width / CGFloat(max(costs.count - 1, 1))
        let x = CGFloat(index) * stepX
        let cost = costs[index]
        let y = yPosition(for: cost, height: height, minCost: minCost, safeRange: safeRange)

        Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        .stroke(.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

        Circle()
            .fill(renderingMode == .accented ? .primary : DS.Color.forPrice(cost, min: minCost, max: maxCost))
            .frame(width: 8, height: 8)
            .position(x: x, y: y)
            .widgetAccentable()

        Circle()
            .fill(.background)
            .frame(width: 4, height: 4)
            .position(x: x, y: y)
    }
}