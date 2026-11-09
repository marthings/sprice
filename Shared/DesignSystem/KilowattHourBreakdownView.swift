import SwiftUI

enum KilowattHourBreakdownStyle {
    case regular
    case compact
}

struct KilowattHourBreakdownView: View {
    let breakdown: KilowattHourBreakdown
    var style: KilowattHourBreakdownStyle = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? DS.Spacing.sm : DS.Spacing.md) {
            stackedBar

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(breakdown.lines) { line in
                    HStack(spacing: DS.Spacing.sm) {
                        Circle()
                            .fill(color(for: line.kind))
                            .frame(width: 8, height: 8)

                        Text(line.title)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)

                        Spacer(minLength: DS.Spacing.sm)

                        Text(line.amountOrePerKWh, format: .number.precision(.fractionLength(1)))
                            .font(DS.Font.micro.monospacedDigit())
                            .foregroundStyle(.primary)

                        Text("öre/kWh")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }

                Divider()

                HStack(spacing: DS.Spacing.sm) {
                    Text("Totalt")
                        .font(DS.Font.semibold(12))
                    Spacer(minLength: DS.Spacing.sm)
                    Text(breakdown.totalKrPerKWh, format: .number.precision(.fractionLength(2)))
                        .font(DS.Font.semibold(12).monospacedDigit())
                    Text("kr/kWh")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
            }

            Text("Siffrorna i listan är utan moms. Momsen ligger på en egen rad. Totalen är vad du betalar.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let missingGridMessage = breakdown.missingGridMessage {
                Label(missingGridMessage, systemImage: "info.circle.fill")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(style == .compact ? DS.Spacing.md : DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var stackedBar: some View {
        GeometryReader { geometry in
            let total = max(breakdown.totalKrPerKWh, 0.0001)
            HStack(spacing: 0) {
                ForEach(breakdown.lines) { line in
                    Rectangle()
                        .fill(color(for: line.kind))
                        .frame(width: geometry.size.width * CGFloat(line.amountKrPerKWh / total))
                }
            }
        }
        .frame(height: style == .compact ? 8 : 12)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func color(for kind: KilowattHourLineKind) -> Color {
        switch kind {
        case .retailEnergy:
            return DS.Color.info
        case .markup:
            return DS.Color.brand
        case .gridTransfer:
            return DS.Color.warning
        case .energyTax:
            return DS.Color.success
        case .certificates:
            return Color.purple
        case .monthlyFees:
            return Color.orange
        case .powerTariff:
            return DS.Color.danger
        case .vat:
            return Color.gray
        }
    }
}
