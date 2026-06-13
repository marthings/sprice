import SwiftUI

struct HistoryCoverageLegend: View {
    let days: [HistoricalEnergySummaryValue]

    private var visibleCoverages: [HistoricalEnergyDataCoverage] {
        HistoricalEnergyDataCoverage.allCases.filter { coverage in
            days.contains { $0.dataCoverage == coverage }
        }
    }

    var body: some View {
        if visibleCoverages.count > 1 {
            HStack(spacing: DS.Spacing.lg) {
                ForEach(visibleCoverages, id: \.self) { coverage in
                    HStack(spacing: DS.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(coverage.displayColor)
                            .frame(width: 12, height: 12)
                        Text(coverage.displayTitle)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
            }
        }
    }
}