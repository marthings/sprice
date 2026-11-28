import Foundation

nonisolated struct ConsumptionInsightsRoute: Hashable, Identifiable {
    enum Period: Hashable {
        case month(monthKey: String, previousMonthKey: String?, periodStart: Date)
        case day(dayKey: String, date: Date)
    }

    let period: Period
    let priceArea: String

    var id: String {
        switch period {
        case .month(let monthKey, _, _):
            return "month|\(monthKey)|\(priceArea)"
        case .day(let dayKey, _):
            return "day|\(dayKey)|\(priceArea)"
        }
    }

    var periodKey: String {
        switch period {
        case .month(let monthKey, _, _):
            return monthKey
        case .day(let dayKey, _):
            return dayKey
        }
    }

    var periodKind: ConsumptionInsightsPeriodKind {
        switch period {
        case .month:
            return .month
        case .day:
            return .day
        }
    }
}

nonisolated enum ConsumptionInsightsPeriodKind: String, Sendable, Equatable {
    case month
    case day
}

nonisolated enum ConsumptionInsightsResolution: String, Sendable, Equatable {
    case quarterHour
    case hourly
    case daily
    case none

    var swedishLabel: String {
        switch self {
        case .quarterHour:
            return "Beräknat på kvartsvärden."
        case .hourly:
            return "Beräknat på timvärden. Kvartsvärden saknas, så topparna är grovare."
        case .daily:
            return "Bara dygnsvärden finns. Grundlasten är osäker, och toppar och dygnsprofil saknas."
        case .none:
            return "Förbrukning saknas, så Vad drog? kan inte räknas ut än."
        }
    }
}

/// Hook for a later outdoor-temperature / heating factor. Unused in this first version.
nonisolated struct ConsumptionInsightsFactors: Sendable, Equatable {
    var temperature: TemperatureInsightFactor?

    static let none = ConsumptionInsightsFactors(temperature: nil)
}

nonisolated struct TemperatureInsightFactor: Sendable, Equatable {
    var meanOutdoorCelsius: Double?
    var heatingShareEstimate: Double?
}

nonisolated struct ConsumptionInsights: Sendable, Equatable {
    let periodKind: ConsumptionInsightsPeriodKind
    let periodStart: Date
    let periodEnd: Date
    let resolution: ConsumptionInsightsResolution
    let factors: ConsumptionInsightsFactors
    let summarySentences: [String]
    let baseload: ConsumptionBaseloadInsight?
    let events: [ConsumptionLoadEvent]
    let eventsUnavailableReason: String?
    let diurnal: ConsumptionDiurnalInsight?
    let diurnalUnavailableReason: String?
    let powerPeak: ConsumptionPowerPeakInsight?
    let powerPeakUnavailableReason: String?

    var evCharging: ConsumptionEVChargingInsight? = nil

    var hasAnythingToShow: Bool {
        baseload != nil || !events.isEmpty || diurnal != nil || powerPeak != nil || evCharging != nil
    }
}

nonisolated struct ConsumptionBaseloadInsight: Sendable, Equatable {
    let powerKW: Double
    let energyKWh: Double
    let costKr: Double
    let previousPowerKW: Double?
    let previousMonthName: String?
    let usedNightPercentile: Bool
}

nonisolated enum ConsumptionLoadEventShape: String, Sendable, Equatable {
    case shortHighPeak
    case longEvenLoad
    case other

    var shapeLabel: String {
        switch self {
        case .shortHighPeak:
            return "Kort hög topp"
        case .longEvenLoad:
            return "Lång jämn last"
        case .other:
            return "Övrig topp"
        }
    }
}

nonisolated struct ConsumptionLoadEvent: Sendable, Equatable, Identifiable {
    let start: Date
    let end: Date
    let energyKWh: Double
    let extraEnergyKWh: Double
    let peakKW: Double
    let costKr: Double
    let shape: ConsumptionLoadEventShape

    var id: Date { start }

    /// One guess per peak, based on shape and time of day. Never treat as fact.
    nonisolated func guess(calendar: Calendar = .energyHistory) -> String {
        let hour = calendar.component(.hour, from: start)
        let weekday = calendar.component(.weekday, from: start)
        let isWeekend = weekday == 1 || weekday == 7

        switch shape {
        case .shortHighPeak:
            if hour >= 6 && hour < 10 {
                return "morgonrusch: kaffe, dusch eller spis?"
            }
            if hour >= 16 && hour < 20 {
                return "middagslagning, ugn eller disk?"
            }
            if hour >= 20 || hour < 6 {
                return "tvätt eller torktumlare på kvällen?"
            }
            return "något som drog mycket en kort stund?"
        case .longEvenLoad:
            if hour >= 21 || hour < 6 {
                return "laddning över natten?"
            }
            if isWeekend {
                return "bastu eller uppvärmning en helg?"
            }
            return "något som gick länge på jämn last?"
        case .other:
            if hour >= 16 && hour < 22 {
                return "kvällssysslor, oklart vad"
            }
            return "något extra, oklart vad"
        }
    }
}

nonisolated struct ConsumptionEVHourBar: Sendable, Equatable, Identifiable {
    let start: Date
    let kWh: Double
    let isCharging: Bool

    var id: Date { start }

    var hour: Int {
        Calendar.energyHistory.component(.hour, from: start)
    }
}

nonisolated struct ConsumptionEVDayProfile: Sendable, Equatable, Identifiable {
    let day: Date
    let hours: [ConsumptionEVHourBar]

    var id: Date { day }
}

nonisolated struct ConsumptionEVChargingSession: Sendable, Equatable, Identifiable {
    let start: Date
    let end: Date
    let energyKWh: Double
    let extraEnergyKWh: Double
    let costKr: Double
    let averagePowerKW: Double

    var id: Date { start }
}

/// A guess, never a fact, built from hours that look like charging.
nonisolated struct ConsumptionEVChargingInsight: Sendable, Equatable {
    let sessions: [ConsumptionEVChargingSession]
    var dayProfiles: [ConsumptionEVDayProfile] = []
    var baseloadKW: Double? = nil

    var energyKWh: Double { sessions.reduce(0) { $0 + $1.energyKWh } }
    var costKr: Double { sessions.reduce(0) { $0 + $1.costKr } }

    var shortSummary: String {
        "Troligen elbil: \(AppFormatters.kWh(energyKWh, fractionLength: 0...0)), ca \(AppFormatters.wholeNumber(costKr)) kr"
    }

    func containsHour(startingAt start: Date) -> Bool {
        sessions.contains { session in
            session.start <= start && start < session.end
        }
    }
}

nonisolated enum ConsumptionHourBand: String, Sendable, Equatable, CaseIterable, Identifiable {
    case night
    case morning
    case day
    case evening

    var id: String { rawValue }

    var swedishName: String {
        switch self {
        case .night: return "natt"
        case .morning: return "morgon"
        case .day: return "dag"
        case .evening: return "kväll"
        }
    }

    var swedishNameCapitalized: String {
        switch self {
        case .night: return "Natt"
        case .morning: return "Morgon"
        case .day: return "Dag"
        case .evening: return "Kväll"
        }
    }

    var hourRangeLabel: String {
        switch self {
        case .night: return "00–06"
        case .morning: return "06–10"
        case .day: return "10–17"
        case .evening: return "17–24"
        }
    }

    nonisolated static func band(forHour hour: Int) -> ConsumptionHourBand {
        switch hour {
        case 0..<6: return .night
        case 6..<10: return .morning
        case 10..<17: return .day
        default: return .evening
        }
    }
}

nonisolated struct ConsumptionHourProfileBar: Sendable, Equatable, Identifiable {
    let hour: Int
    let averageKWh: Double
    let totalCostKr: Double

    var id: Int { hour }
}

nonisolated struct ConsumptionHourBandCost: Sendable, Equatable, Identifiable {
    let band: ConsumptionHourBand
    let costKr: Double
    let energyKWh: Double

    var id: String { band.rawValue }
}

nonisolated struct ConsumptionShiftTip: Sendable, Equatable {
    let shiftKWh: Double
    let fromBand: ConsumptionHourBand
    let toBand: ConsumptionHourBand
    let savedKr: Double
}

nonisolated struct ConsumptionDiurnalInsight: Sendable, Equatable {
    let hourBars: [ConsumptionHourProfileBar]
    let bands: [ConsumptionHourBandCost]
    let dominantBand: ConsumptionHourBand
    let expensiveShareKWh: Double
    let expensiveShareKr: Double
    let shiftTip: ConsumptionShiftTip?
}

nonisolated struct ConsumptionPowerPeakInsight: Sendable, Equatable {
    let hourStart: Date
    let powerKW: Double
    let effectTariffCostKr: Double?
    let usesAveragePeaks: Bool
    let includeHypotheticalCost: Bool
}
