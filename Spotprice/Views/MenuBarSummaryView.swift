//
//  MenuBarSummaryView.swift
//  Spotprice
//

import SwiftUI

struct MenuBarSummaryView: View {
    @ObservedObject var viewModel: SummaryViewModel
    @ObservedObject var spotPriceViewModel: SpotPriceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            headerView
            contentView
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("Prisanalys")
                .font(DS.Font.semibold(14))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: {
                Task {
                    await spotPriceViewModel.load()
                    await viewModel.loadSummary()
                }
            }) {
                Group {
                    if spotPriceViewModel.state == .loading || viewModel.state.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .controlSize(.mini)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(DS.Font.semibold(10))
                    }
                }
                .frame(width: DS.Size.statCardIconSize, height: DS.Size.statCardIconSize)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(.blue.opacity(0.2)))
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(spotPriceViewModel.state == .loading || viewModel.state.isLoading)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle:
            Text("Väntar på uppdatering")
                .font(DS.Font.medium(11))
                .foregroundStyle(.secondary)

        case .loadingConsumption, .analyzing:
            loadingView

        case .loaded(let summary, let priceChange, _, let previousMonth):
            loadedView(summary: summary, priceChange: priceChange, previousMonth: previousMonth)

        case .noConsumptionConfigured:
            noConfigView

        case .failed:
            failedView
        }
    }

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .controlSize(.mini)
                    .tint(.blue)

                Text(loadingText(for: viewModel.state))
                    .font(DS.Font.medium(11))
                    .foregroundStyle(.primary)

                Spacer()
            }

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.quaternary)
                    .frame(height: DS.Spacing.xxs)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.blue.gradient)
                            .frame(width: geometry.size.width * progressValue, height: DS.Spacing.xxs)
                            .animation(.easeInOut(duration: 0.3), value: progressValue)
                    }
            }
            .frame(height: DS.Spacing.xxs)
        }
    }

    private func loadedView(summary: String, priceChange: Double?, previousMonth: String?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Price change badge
            if let change = priceChange, let prevMonth = previousMonth {
                priceChangeBadge(change: change, previousMonth: prevMonth)
            }

            // AI analysis text
            Text(summary)
                .font(DS.Font.medium(11))
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
        }
    }

    private func priceChangeBadge(change: Double, previousMonth: String) -> some View {
        let isHigher = change >= 0
        let arrow = isHigher ? "arrow.up" : "arrow.down"
        let color: Color = isHigher ? DS.Color.error : DS.Color.success
        let changeText = String(format: "%.0f", abs(change))
        let comparisonText = isHigher ? "dyrare" : "billigare"

        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: arrow)
                .font(DS.Font.semibold(10))

            Text("\(changeText)% \(comparisonText) vs \(previousMonth)")
                .font(DS.Font.semibold(11))
        }
        .foregroundStyle(color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
        }
    }

    private var noConfigView: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "bolt.slash")
                .font(DS.Font.caption)
                .foregroundStyle(.secondary)

            Text("Konfigurera förbrukning i inställningar")
                .font(DS.Font.medium(11))
                .foregroundStyle(.secondary)
        }
    }

    private var failedView: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.warning)

            Text("Kunde inte hämta prisanalys")
                .font(DS.Font.medium(11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var progressValue: Double {
        switch viewModel.state {
        case .loadingConsumption: return 0.4
        case .analyzing: return 0.8
        default: return 0.0
        }
    }

    private func loadingText(for state: SummaryViewModel.State) -> String {
        switch state {
        case .loadingConsumption: return "Hämtar förbrukningsdata..."
        case .analyzing: return "Analyserar med AI..."
        default: return "Laddar..."
        }
    }
}
