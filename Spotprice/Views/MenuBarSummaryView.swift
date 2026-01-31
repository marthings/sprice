//
//  MenuBarSummaryView.swift
//  Spotprice
//

import SwiftUI

struct MenuBarSummaryView: View {
    @ObservedObject var viewModel: SummaryViewModel
    @ObservedObject var spotPriceViewModel: SpotPriceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            contentView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("Marknadsläge")
                .font(.custom("Avenir", size: 14).weight(.semibold))
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
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .frame(width: 24, height: 24)
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
                .font(.custom("Avenir", size: 11).weight(.medium))
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .controlSize(.mini)
                    .tint(.blue)

                Text(loadingText(for: viewModel.state))
                    .font(.custom("Avenir", size: 11).weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()
            }

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.quaternary)
                    .frame(height: 2)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.blue.gradient)
                            .frame(width: geometry.size.width * progressValue, height: 2)
                            .animation(.easeInOut(duration: 0.3), value: progressValue)
                    }
            }
            .frame(height: 2)
        }
    }

    private func loadedView(summary: String, url: URL, isPreviousMonth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: isPreviousMonth ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isPreviousMonth ? .orange : .green)

                Text(isPreviousMonth ? "Föreg. månad" : "Uppdaterad")
                    .font(.custom("Avenir", size: 10).weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(summary)
                .font(.custom("Avenir", size: 11).weight(.medium))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)

            Link(destination: url) {
                HStack(spacing: 4) {
                    Text("Läs hela rapporten")
                        .font(.custom("Avenir", size: 10).weight(.semibold))

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .glassEffect(.regular.tint(.blue.opacity(0.1)), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private var failedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)

            Text("Kunde inte hämta marknadsöversikten")
                .font(.custom("Avenir", size: 11).weight(.medium))
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
