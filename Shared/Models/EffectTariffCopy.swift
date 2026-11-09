import Foundation

nonisolated enum EffectTariffCopy {
    nonisolated static let toggleTitle = "Räkna med effektavgift"
    nonisolated static let explanation = "Visar vad toppen hade kostat om elnätet tog betalt för den. Elnätsbolag får i dag inte ta betalt för effekttoppen."
    nonisolated static let lineTitle = "Effektavgift (om den räknades)"
    nonisolated static let missingRate = "Ingen effektavgift i dina elnätsuppgifter, så toppen syns bara som kW."
    nonisolated static let dailyBarsNote = "Den syns inte i dygnsstaplarna — det är en månadsavgift, inte en kostnad per dag."
}
