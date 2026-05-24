//
//  ChartCalloutView.swift
//  Spotprice
//

import SwiftUI

struct ChartCalloutView: View {
    let bucket: PriceBucket
    let dayData: DayChartData
    let profile: CostProfile
    
    // Cache service to avoid recreating
    private static let totalCostService = TotalCostService()

    /// Price category and color based on contract type
    /// - For spot contracts: market tertiles (low/medium/high)
    /// - For fixed/variable contracts: comparison to user's contract price
    private var priceCategory: PriceCategory {
        // For fixed/variable contracts, compare market to user's contract
        if !profile.isSpotFollowingRetailContract, let contractPrice = profile.contractPriceOrePerKWh {
            let difference = bucket.orePerKWh - contractPrice
            let percentDiff = abs(difference / contractPrice)
            
            // Market is higher than user's contract = good deal (user is saving)
            if difference > 0 {
                // Market is 20%+ higher = very good deal
                if percentDiff >= 0.20 {
                    return .low  // Show as "Billigt" (user has good price)
                }
                // Market is slightly higher = decent
                else {
                    return .medium
                }
            }
            // Market is lower than user's contract = losing money
            else {
                // Market is 20%+ lower = bad deal
                if percentDiff >= 0.20 {
                    return .high  // Show as "Dyrt" (user is overpaying)
                }
                // Market is slightly lower = okay
                else {
                    return .medium
                }
            }
        }
        // For spot contracts, use market tertiles
        else {
            return DS.Color.categoryForPrice(bucket.orePerKWh, min: dayData.minOre, max: dayData.maxOre)
        }
    }

    private var priceColor: Color {
        DS.Color.forCategory(priceCategory)
    }
    
    private var totalCostPerKWh: Double {
        Self.totalCostService.calculatePricePerKWh(
            spotPriceOre: bucket.orePerKWh,
            profile: profile
        )
    }
    
    private var costBreakdown: EnhancedCost {
        Self.totalCostService.calculateTotalCost(
            kWh: 1.0,
            spotPriceOre: bucket.orePerKWh,
            profile: profile,
            hoursInPeriod: 1.0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Time range with accessible category icon
            HStack(spacing: DS.Spacing.sm) {

                Text("\(timeLabel(bucket.start))–\(timeLabel(bucket.end))")
                    .font(DS.Font.semibold(11))
                    .foregroundStyle(.primary)

                // Show market quarter price for all contract types
                HStack(spacing: DS.Spacing.xs) {

                    Text("\(Int(bucket.orePerKWh.rounded()))")
                        .font(DS.Font.medium(11).monospacedDigit())
                        .foregroundStyle(priceColor)
                    Text("öre/kWh")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                
                // Badge shows different meaning based on contract type
                // - Spot: market level (Lågt/Medel/Högt)
                // - Fixed/Variable: contract comparison (Billigt/OK/Dyrt)
                PriceLevelBadge(
                    category: priceCategory,
                    style: .compact
                )
            }

            // For spot-following contracts, show total cost
            if profile.isSpotFollowingRetailContract {
                Divider()
                    .padding(.vertical, DS.Spacing.xxs)
                
                HStack(spacing: DS.Spacing.xs) {
                    Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                        .font(DS.Font.bold(16).monospacedDigit())
                        .foregroundStyle(.blue)
                    Text("kr/kWh totalt")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.secondary)
                }
                
                // Detailed breakdown - show top 3 components + "Övrigt"
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(topBreakdownComponents(for: costBreakdown), id: \.label) { component in
                        BreakdownRow(
                            label: component.label,
                            value: component.value,
                            isMainComponent: component.isMain
                        )
                    }
                }
                .padding(.top, DS.Spacing.xxs)
            }
            // For fixed/variable contracts, show contract price as reference
            else if let contractPrice = profile.contractPriceOrePerKWh {
                Divider()
                    .padding(.vertical, DS.Spacing.xxs)
                
                let difference = bucket.orePerKWh - contractPrice
                let percentDiff = abs((difference / contractPrice) * 100)
                
                // When market is higher than contract = good deal (user saves money)
                let isGoodDeal = difference > 0
                let displayColor = isGoodDeal ? DS.Color.success : DS.Color.danger
                let iconName = isGoodDeal ? "checkmark.circle.fill" : "xmark.circle.fill"
                let labelText = isGoodDeal ? "Sparar:" : "Förlorar:"
                
                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: iconName)
                            .font(.system(size: 10))
                            .foregroundStyle(displayColor)
                        Text(labelText)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                        Text("\(percentDiff, specifier: "%.0f")%")
                            .font(DS.Font.medium(11).monospacedDigit())
                            .foregroundStyle(displayColor)
                    }
                    Spacer()
                    // Show total cost breakdown even for fixed contracts
                    
                    HStack(spacing: DS.Spacing.xs) {
                        Text(totalCostPerKWh, format: .number.precision(.fractionLength(2)))
                            .font(DS.Font.bold(14).monospacedDigit())
                            .foregroundStyle(.blue)
                        Text("kr/kWh")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    }
                }
                
                
                // Detailed breakdown for fixed/variable contracts - show top 3 + "Övrigt"
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(topBreakdownComponents(for: costBreakdown), id: \.label) { component in
                        BreakdownRow(
                            label: component.label,
                            value: component.value,
                            isMainComponent: component.isMain
                        )
                    }
                }
                .padding(.top, DS.Spacing.xxs)
            }



        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(.quaternary, lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.15), radius: DS.Spacing.sm, x: 0, y: DS.Spacing.xs)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
    }
    
    // MARK: - Breakdown Helpers
    
    private func topBreakdownComponents(for cost: EnhancedCost) -> [BreakdownComponent] {
        var components: [BreakdownComponent] = []
        
        // Always include main retail energy component
        components.append(BreakdownComponent(
            label: profile.retailContractDisplayName,
            value: cost.spotCostKr,
            isMain: true
        ))
        
        // Collect all other components
        var otherComponents: [(label: String, value: Double)] = []
        
        // Retail markup (only for spot contracts)
        if profile.retailContractType == .spotPriceMarkup && cost.providerSurchargeKr > 0 {
            otherComponents.append(("Elhandelsavgifter", cost.providerSurchargeKr))
        }
        
        // Retail monthly fee
        if cost.providerMonthlyFeeKr > 0 {
            otherComponents.append(("Elhandel månadavgift", cost.providerMonthlyFeeKr))
        }
        
        // Grid transfer
        if cost.gridEnergyCostKr > 0 {
            otherComponents.append(("Elnätsavgift", cost.gridEnergyCostKr))
        }
        
        // Grid fixed fee
        if cost.fixedFeeCostKr > 0 {
            otherComponents.append(("Elnät månadavgift", cost.fixedFeeCostKr))
        }
        
        // Energy tax (always significant)
        otherComponents.append(("Energiskatt", cost.energyTaxKr))
        
        // Certificate fee
        if cost.certificateFeeKr > 0 {
            otherComponents.append(("Elcertifikat", cost.certificateFeeKr))
        }
        
        // Effect tariff
        if cost.powerTariffCostKr > 0 {
            otherComponents.append(("Effektavgift", cost.powerTariffCostKr))
        }
        
        // Sort by value descending
        otherComponents.sort { $0.value > $1.value }
        
        // Take top 2 (we already have 1 main component, so total will be 3 + "Övrigt")
        let topTwo = Array(otherComponents.prefix(2))
        let remaining = Array(otherComponents.dropFirst(2))
        
        // Add top 2 components
        for component in topTwo {
            components.append(BreakdownComponent(
                label: component.label,
                value: component.value,
                isMain: false
            ))
        }
        
        // Add "Övrigt" if there are remaining components
        if !remaining.isEmpty {
            let othersTotal = remaining.reduce(0) { $0 + $1.value }
            components.append(BreakdownComponent(
                label: "Övrigt",
                value: othersTotal,
                isMain: false
            ))
        }
        
        return components
    }
}

// MARK: - Breakdown Component

private struct BreakdownComponent {
    let label: String
    let value: Double
    let isMain: Bool
}

// MARK: - Breakdown Row

private struct BreakdownRow: View {
    let label: String
    let value: Double
    var isMainComponent: Bool = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(isMainComponent ? .primary : DS.Color.secondary)
            Spacer()
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(DS.Font.medium(10).monospacedDigit())
                .foregroundStyle(isMainComponent ? .primary : DS.Color.secondary)
            Text("kr")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.secondary)
        }
    }
}
