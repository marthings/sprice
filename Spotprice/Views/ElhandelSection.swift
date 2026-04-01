//
//  ElhandelSection.swift
//  Spotprice
//

import SwiftUI

struct ElhandelSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        let metadata = ProviderCostMetadata.forProvider(settings.selectedProviderId)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Elhandel")
                    .font(DS.Font.bold(12))
                    .foregroundStyle(.primary)

                Spacer()

                // Badge driven by metadata
                if let badgeText = metadata.badgeText {
                    HStack(spacing: 4) {
                        if let icon = metadata.badgeIcon {
                            Image(systemName: icon)
                                .font(.system(size: 10))
                                .foregroundStyle(colorForBadge(metadata.badgeColor))
                        }
                        Text(badgeText)
                            .font(DS.Font.regular(9))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Surcharge field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Påslag (öre/kWh inkl. moms)")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(.secondary)

                    if settings.providerSurchargePerKWh == 0, let hint = metadata.surchargeHint {
                        Text(hint)
                            .font(DS.Font.regular(9))
                            .foregroundStyle(.blue)
                    }
                }

                TextField("0", value: $settings.providerSurchargePerKWh, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .help("Lämna 0 för att använda provider-defaults (om tillgängligt)")
            }

            // Monthly fee field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Månadsavgift (kr)")
                        .font(DS.Font.regular(11))
                        .foregroundStyle(.secondary)

                    if settings.providerMonthlyFee == 0, let hint = metadata.monthlyFeeHint {
                        Text(hint)
                            .font(DS.Font.regular(9))
                            .foregroundStyle(.blue)
                    }
                }

                TextField("0", value: $settings.providerMonthlyFee, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .help("Lämna 0 för att använda provider-defaults (om tillgängligt)")
            }

            // Help text driven by metadata
            Text(metadata.helpText)
                .font(DS.Font.regular(11))
                .foregroundStyle(.secondary)
        }
    }

    private func colorForBadge(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        default: return .secondary
        }
    }
}
