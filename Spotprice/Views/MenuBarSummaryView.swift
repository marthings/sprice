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
            Text("Marknadsläge")
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
                .glassEffect(.regular.tint(.blue.opacity(0.2)), in: .circle)
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

        case .loadingURL, .fetchingReport, .summarizing:
            loadingView

        case .loaded(let summary, let url, let isPreviousMonth):
            loadedView(summary: summary, url: url, isPreviousMonth: isPreviousMonth)

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

    private func loadedView(summary: String, url: URL, isPreviousMonth: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isPreviousMonth ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(isPreviousMonth ? DS.Color.warning : DS.Color.success)

                Text(isPreviousMonth ? "Föreg. månad" : "Uppdaterad")
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(summary)
                .font(DS.Font.medium(11))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)

            Link(destination: url) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Läs hela rapporten")
                        .font(DS.Font.semibold(10))

                    Image(systemName: "arrow.up.right")
                        .font(DS.Font.regular(9))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.xxs + 1)
                .glassEffect(.regular.tint(.blue.opacity(0.1)), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private var failedView: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.warning)

            Text("Kunde inte hämta marknadsöversikten")
                .font(DS.Font.medium(11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var progressValue: Double {
        switch viewModel.state {
        case .loadingURL: return 0.3
        case .fetchingReport: return 0.6
        case .summarizing: return 0.9
        default: return 0.0
        }
    }

    private func loadingText(for state: SummaryViewModel.State) -> String {
        switch state {
        case .loadingURL: return "Förbereder månadsdata..."
        case .fetchingReport: return "Hämtar marknadsrapport..."
        case .summarizing: return "Analyserar med AI..."
        default: return "Laddar..."
        }
    }
}
