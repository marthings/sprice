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
                    let rawMinPrice = prices.min() ?? 0
                    let rawMaxPrice = prices.max() ?? 0
                    let minPrice = rawMinPrice * 0.95
                    let maxPrice = rawMaxPrice * 1.05

                    Chart {
                        ForEach(payload.day.buckets) { bucket in
                            AreaMark(
                                x: .value("Hour", bucket.start),
                                yStart: .value("Baslinje", minPrice),
                                yEnd: .value("öre/kWh", bucket.orePerKWh)
                            )
                            .foregroundStyle(areaGradient(for: payload.day.buckets, min: rawMinPrice, max: rawMaxPrice))
                        }

                        ForEach(payload.day.buckets) { bucket in
                            LineMark(
                                x: .value("Hour", bucket.start),
                                y: .value("öre/kWh", bucket.orePerKWh),
                                series: .value("Price", "Market")
                            )
                            .foregroundStyle(lineGradient(for: payload.day.buckets, min: rawMinPrice, max: rawMaxPrice))
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
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

    private func areaGradient(for buckets: [PriceBucket], min: Double, max: Double) -> LinearGradient {
        LinearGradient(
            colors: buckets.map { priceColor(for: $0.orePerKWh, min: min, max: max).opacity(0.26) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func lineGradient(for buckets: [PriceBucket], min: Double, max: Double) -> LinearGradient {
        LinearGradient(
            colors: buckets.map { priceColor(for: $0.orePerKWh, min: min, max: max) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func priceColor(for price: Double, min: Double, max: Double) -> Color {
        DS.Color.forPrice(price, min: min, max: max)
    }
}

#Preview {
    SpotPriceChartView()
}
