import SwiftUI
import Charts

struct SpotPriceChartView: View {
    @State private var viewModel = SpotPriceViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading spot prices...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: 16) {
                    Text("Error: \(message)")
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let payload):
                VStack(alignment: .leading, spacing: 12) {
                    Text(payload.currentDisplay + " öre")
                        .font(.title2)
                        .bold()

                    let prices = payload.day.buckets.map { $0.orePerKWh }
                    let minPrice = (prices.min() ?? 0) * 0.95
                    let maxPrice = (prices.max() ?? 0) * 1.05

                    Chart {
                        ForEach(payload.day.buckets) { bucket in
                            LineMark(
                                x: .value("Hour", bucket.start),
                                y: .value("öre/kWh", bucket.orePerKWh)
                            )
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                            AxisGridLine()
                            AxisTick()
                            if let date = value.as(Date.self) {
                                AxisValueLabel { Text(date.formatted(.dateTime.hour())) }
                            }
                        }
                    }
                    .chartYScale(domain: minPrice...maxPrice)
                    .frame(height: 240)
                }
                .padding()
            }
        }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
    }
}

#Preview {
    SpotPriceChartView()
}
