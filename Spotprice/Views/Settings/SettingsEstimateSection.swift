//
//  SettingsEstimateSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsEstimateSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Uppskattning")
                    .font(DS.Font.bold(12))
                    .foregroundStyle(.primary)

                Spacer()

                if let label = settings.costProfile.confidence.menuBarLabel {
                    Text(label)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(.quaternary.opacity(0.6), in: .capsule)
                }
            }

            SettingsSummaryRow(title: retailContractSummaryTitle, value: retailContractSummaryValue)
            SettingsSummaryRow(
                title: "Elnät",
                value: settings.costProfile.gridMonthlyFee == nil && settings.costProfile.gridTransferOrePerKWh == nil
                    ? "Ej inkluderat"
                    : "Inkluderat"
            )
            SettingsSummaryRow(
                title: "Effektavgift",
                value: settings.costProfile.effectTariff == nil ? "Av" : "På"
            )

            Text("Sprice visar ett pris baserat på tillgängliga uppgifter. Elnätskostnad ingår först när du lägger till dina elnätsuppgifter.")
                .font(DS.Font.regular(11))
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var retailContractSummaryTitle: String {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            return "Elhandelsavgifter"
        case .variableMonthlyPrice:
            return "Rörligt månadspris"
        case .fixedPrice:
            return "Fast pris"
        }
    }

    private var retailContractSummaryValue: String {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            return "\(settings.costProfile.retailerMarkupOrePerKWh.formatted(.number.precision(.fractionLength(0...2)))) öre/kWh"
        case .variableMonthlyPrice, .fixedPrice:
            if let contractPrice = settings.costProfile.contractPriceOrePerKWh {
                return "\(contractPrice.formatted(.number.precision(.fractionLength(0...2)))) öre/kWh"
            }
            return "Ej angivet"
        }
    }
}