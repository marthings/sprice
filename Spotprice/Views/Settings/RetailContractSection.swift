//
//  RetailContractSection.swift
//  Spotprice
//

import SwiftUI

struct RetailContractSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        Section {
            Picker("Avtalsmodell", selection: $settings[retailContractType: SettingsBind.retailContractType]) {
                Text("Kvartspris").tag(RetailContractType.spotPriceMarkup)
                Text("Rörligt").tag(RetailContractType.variableMonthlyPrice)
                Text("Fast").tag(RetailContractType.fixedPrice)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            LabeledContent("Aktivt", value: activeContractTitle)

            contractFields
            monthlyFeeField

            contractValueField(
                title: "Jämför med fast pris",
                placeholder: "120",
                value: $settings.compareFixedPriceOrePerKWh,
                suffix: "öre/kWh"
            )

            Button("Återställ standard") {
                settings.resetRetailContractToDefaults()
            }
        } header: {
            HStack {
                Text("Avtal")
                Spacer()
                if settings.costProfile.hasCustomRetailContract {
                    Text("Anpassat")
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(activeContractDescription)
                Text("Förbrukningsdata hämtas från datakällan, men elhandelskostnaden kommer från dina egna avtalsvärden.")
                Text("Jämför med fast pris används bara för att visa skillnaden mot spot. Standard är 120 öre/kWh inklusive moms.")
            }
        }
    }

    @ViewBuilder
    private var contractFields: some View {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            contractValueField(
                title: "Elhandelsavgifter",
                placeholder: "4",
                value: $settings[retailerMarkupOre: SettingsBind.retailerMarkupOre],
                suffix: "öre/kWh"
            )
        case .variableMonthlyPrice:
            contractValueField(
                title: "Avtalat elpris",
                placeholder: "84,30",
                value: $settings[contractPriceOre: SettingsBind.contractPriceOre],
                suffix: "öre/kWh"
            )
        case .fixedPrice:
            contractValueField(
                title: "Fast elpris",
                placeholder: "103,30",
                value: $settings[contractPriceOre: SettingsBind.contractPriceOre],
                suffix: "öre/kWh"
            )
        }
    }

    private var monthlyFeeField: some View {
        contractValueField(
            title: "Månadsavgift",
            placeholder: "0",
            value: $settings[retailerMonthlyFee: SettingsBind.retailerMonthlyFee],
            suffix: "kr/mån"
        )
    }

    private var activeContractTitle: String {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            return "Kvartspris"
        case .variableMonthlyPrice:
            return "Rörligt månadspris"
        case .fixedPrice:
            return "Fast pris"
        }
    }

    private var activeContractDescription: String {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            return "Elhandelskostnaden följer Nord Pools spotpris per kvart plus dina elhandelsavgifter. Påslag anges som på fakturan, inklusive moms. Spotpriset hämtas utan moms."
        case .variableMonthlyPrice:
            return "Använd ditt avtalade elpris i öre/kWh från rörligt månadspris istället för kvartens spotpris. Priset anges inklusive moms."
        case .fixedPrice:
            return "Använd ditt fasta avtalade elpris i öre/kWh istället för kvartens spotpris. Priset anges inklusive moms."
        }
    }

    private func contractValueField(
        title: String,
        placeholder: String,
        value: Binding<Double>,
        suffix: String
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: DS.Spacing.xs) {
                TextField(placeholder, value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: DS.Size.settingsFieldWidth)
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
    }
}