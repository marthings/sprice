//
//  RetailContractSection.swift
//  Spotprice
//

import SwiftUI

struct RetailContractSection: View {
    @Bindable var settings: ConsumptionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            contractTypePicker
            activeContractSummary
            contractFields
            monthlyFeeField
            resetButton
            helperText
        }
    }

    private var header: some View {
        HStack {
            Text("Elhandel")
                .font(DS.Font.bold(12))
                .foregroundStyle(.primary)

            Spacer()

            if settings.costProfile.hasCustomRetailContract {
                Text("Anpassat")
                    .font(DS.Font.regular(9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contractTypePicker: some View {
        Picker("Avtalsmodell", selection: retailContractTypeBinding) {
            Text("Kvartspris").tag(RetailContractType.spotPriceMarkup)
            Text("Rörligt").tag(RetailContractType.variableMonthlyPrice)
            Text("Fast").tag(RetailContractType.fixedPrice)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var activeContractSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Aktivt: \(activeContractTitle)")
                .font(DS.Font.medium(11))
                .foregroundStyle(.primary)

            Text(activeContractDescription)
                .font(DS.Font.regular(11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var contractFields: some View {
        switch settings.costProfile.retailContractType {
        case .spotPriceMarkup:
            contractValueField(
                title: "Elhandelsavgifter (öre/kWh inkl. moms)",
                placeholder: "4",
                value: retailerMarkupBinding,
                help: "Ange avgifterna från ditt kvartsprisavtal."
            )
        case .variableMonthlyPrice:
            contractValueField(
                title: "Avtalat elpris (öre/kWh inkl. moms)",
                placeholder: "84,30",
                value: contractPriceBinding,
                help: "Ange det avtalade elpriset i öre/kWh från ditt rörliga månadspris."
            )
        case .fixedPrice:
            contractValueField(
                title: "Fast elpris (öre/kWh inkl. moms)",
                placeholder: "103,30",
                value: contractPriceBinding,
                help: "Ange ditt fasta avtalade elpris i öre/kWh."
            )
        }
    }

    private var monthlyFeeField: some View {
        contractValueField(
            title: "Månadsavgift (kr/mån)",
            placeholder: "0",
            value: retailerMonthlyFeeBinding,
            help: "Ange månadsavgiften från ditt elhandelsavtal."
        )
    }

    private var resetButton: some View {
        Button("Återställ standard") {
            resetRetailContract()
        }
        .font(DS.Font.medium(11))
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }

    private var helperText: some View {
        Text("Förbrukningsdata hämtas från datakällan, men elhandelskostnaden kommer från dina egna avtalsvärden.")
            .font(DS.Font.regular(11))
            .foregroundStyle(.secondary)
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
            return "Elhandelskostnaden följer Nord Pools spotpris per kvart plus dina elhandelsavgifter."
        case .variableMonthlyPrice:
            return "Använd ditt avtalade elpris i öre/kWh från rörligt månadspris istället för kvartens spotpris."
        case .fixedPrice:
            return "Använd ditt fasta avtalade elpris i öre/kWh istället för kvartens spotpris."
        }
    }

    private func contractValueField(
        title: String,
        placeholder: String,
        value: Binding<Double>,
        help: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DS.Font.regular(11))
                .foregroundStyle(.secondary)

            TextField(placeholder, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .help(help)
        }
    }

    private var retailContractTypeBinding: Binding<RetailContractType> {
        Binding(
            get: { settings.costProfile.retailContractType },
            set: { newValue in
                updateRetailContractType(newValue)
            }
        )
    }

    private var retailerMarkupBinding: Binding<Double> {
        Binding(
            get: { settings.costProfile.retailerMarkupOrePerKWh },
            set: { newValue in
                updateSpotPriceMarkup(newValue)
            }
        )
    }

    private var contractPriceBinding: Binding<Double> {
        Binding(
            get: { settings.costProfile.contractPriceOrePerKWh ?? 0 },
            set: { newValue in
                updateContractPrice(newValue)
            }
        )
    }

    private var retailerMonthlyFeeBinding: Binding<Double> {
        Binding(
            get: { settings.costProfile.retailerMonthlyFee },
            set: { newValue in
                updateMonthlyFee(newValue)
            }
        )
    }

    private func updateRetailContractType(_ type: RetailContractType) {
        let contractPrice = type == .spotPriceMarkup ? nil : settings.costProfile.contractPriceOrePerKWh
        settings.costProfile = settings.costProfile
            .settingRetailContract(
                type: type,
                contractPriceOrePerKWh: contractPrice,
                retailContractSource: .userEntered,
                confidence: .userConfigured,
                source: .userEntered
            )
    }

    private func updateSpotPriceMarkup(_ markup: Double) {
        settings.costProfile = settings.costProfile
            .settingRetailContract(
                type: .spotPriceMarkup,
                retailerMarkupOrePerKWh: markup,
                contractPriceOrePerKWh: nil,
                retailContractSource: .userEntered,
                confidence: .userConfigured,
                source: .userEntered
            )
    }

    private func updateContractPrice(_ price: Double) {
        settings.costProfile = settings.costProfile
            .settingRetailContract(
                type: settings.costProfile.retailContractType,
                contractPriceOrePerKWh: price,
                retailContractSource: .userEntered,
                confidence: .userConfigured,
                source: .userEntered
            )
    }

    private func updateMonthlyFee(_ monthlyFee: Double) {
        settings.costProfile = settings.costProfile
            .settingRetailContract(
                type: settings.costProfile.retailContractType,
                contractPriceOrePerKWh: settings.costProfile.contractPriceOrePerKWh,
                retailerMonthlyFee: monthlyFee,
                retailContractSource: .userEntered,
                confidence: .userConfigured,
                source: .userEntered
            )
    }

    private func resetRetailContract() {
        settings.costProfile = settings.costProfile
            .settingRetailContract(
                type: .spotPriceMarkup,
                retailerMarkupOrePerKWh: CostProfile.SwedishDefaults.retailerMarkupOrePerKWh,
                contractPriceOrePerKWh: nil,
                retailerMonthlyFee: CostProfile.SwedishDefaults.retailerMonthlyFee,
                retailContractSource: .defaultEstimate
            )
            .applyingInferredConfidence(configuredSource: .userEntered)
    }
}
