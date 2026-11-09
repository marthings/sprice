//
//  SettingsEstimateSection.swift
//  Spotprice
//

import SwiftUI

struct SettingsEstimateSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        Section {
            if let label = settings.costProfile.confidence.menuBarLabel {
                LabeledContent("Status", value: label)
            }

            SettingsSummaryRow(title: retailContractSummaryTitle, value: retailContractSummaryValue)
            SettingsSummaryRow(
                title: "Elnät",
                value: settings.costProfile.gridMonthlyFee == nil && settings.costProfile.gridTransferOrePerKWh == nil
                    ? "Ej inkluderat"
                    : "Inkluderat"
            )
            SettingsSummaryRow(
                title: EffectTariffCopy.toggleTitle,
                value: settings.includeHypotheticalEffectTariff ? "På" : "Av"
            )
        } header: {
            Text("Uppskattning")
        } footer: {
            Text("Sprice visar ett pris baserat på tillgängliga uppgifter. Elnätskostnad ingår först när du lägger till dina elnätsuppgifter.")
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