import Foundation

/// Everyday household examples for the Cost tab. kWh values are order-of-magnitude
/// figures for a typical Swedish home, not a measurement of this household.
struct HouseholdCostExample: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let kWh: Double
    let hoursInPeriod: Double

    /// Shared by iOS and macOS so the two apps cannot drift apart.
    static let catalog: [HouseholdCostExample] = [
        HouseholdCostExample(
            id: "shower",
            title: "Dusch",
            subtitle: "10 min · ~1,5 kWh",
            kWh: 1.5,
            hoursInPeriod: 10.0 / 60.0
        ),
        HouseholdCostExample(
            id: "oven",
            title: "Pizza i ugn",
            subtitle: "~1,1 kWh",
            kWh: 1.1,
            hoursInPeriod: 0.5
        ),
        HouseholdCostExample(
            id: "dishwasher",
            title: "Diskmaskin",
            subtitle: "ett program · ~1 kWh",
            kWh: 1.0,
            hoursInPeriod: 2.0
        ),
        HouseholdCostExample(
            id: "laundry",
            title: "Tvättmaskin",
            subtitle: "40 °C · ~0,8 kWh",
            kWh: 0.8,
            hoursInPeriod: 2.0
        ),
        HouseholdCostExample(
            id: "heat-pump",
            title: "Värmepump",
            subtitle: "1 dygn · ~24 kWh",
            kWh: 24.0,
            hoursInPeriod: 24.0
        ),
        HouseholdCostExample(
            id: "ev-charge",
            title: "Ladda bilen",
            subtitle: "hemma · ~15 kWh",
            kWh: 15.0,
            hoursInPeriod: 8.0
        )
    ]

    static let catalogFootnote =
        "Ungefärliga värden. Duschen räknas med elvarmvattenberedare. Billaddningen är en vanlig hemmaladdning, inte ett fullt batteri."
}
