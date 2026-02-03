import Foundation
import Combine
import SwiftUI

@Observable @MainActor
final class SummaryViewModel {
    enum State: Equatable {
        case idle
        case loadingConsumption
        case analyzing
        case loaded(
            summary: String,
            priceChangePercent: Double?,
            currentMonth: String,
            previousMonth: String?
        )
        case noConsumptionConfigured
        case failed(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.loadingConsumption, .loadingConsumption),
                 (.analyzing, .analyzing),
                 (.noConsumptionConfigured, .noConsumptionConfigured):
                return true
            case (.loaded(let lS, let lP, let lC, let lPM), .loaded(let rS, let rP, let rC, let rPM)):
                return lS == rS && lP == rP && lC == rC && lPM == rPM
            case (.failed(let lE), .failed(let rE)):
                return lE == rE
            default:
                return false
            }
        }
    }

    private(set) var state: State = .idle

    private let consumptionService: ConsumptionService
    private let spotPriceService: SpotPriceService
    private let openAIService: OpenAIService

    init(
        consumptionService: ConsumptionService? = nil,
        spotPriceService: SpotPriceService? = nil,
        openAIService: OpenAIService? = nil
    ) {
        self.consumptionService = consumptionService ?? ConsumptionService()
        self.spotPriceService = spotPriceService ?? SpotPriceService()
        self.openAIService = openAIService ?? OpenAIService()
    }

    func loadSummary() async {
        // Prevent loading if already in progress
        if case .loadingConsumption = state { return }
        if case .analyzing = state { return }

        // Check if consumption is configured
        guard ConsumptionSettings.shared.isConfigured else {
            state = .noConsumptionConfigured
            return
        }

        state = .loadingConsumption

        do {
            // 1. Fetch monthly comparison data
            let comparison = try await consumptionService.fetchMonthlyComparison(spotPriceService: spotPriceService)

            state = .analyzing

            // 2. Get AI analysis
            let summary = try await openAIService.analyzeMonthlyComparison(comparison)

            // 3. Update state with results
            state = .loaded(
                summary: summary,
                priceChangePercent: comparison.priceChangePercent,
                currentMonth: comparison.currentMonthName,
                previousMonth: comparison.previousMonthName
            )

        } catch let error as DisplayableError {
            state = .failed(error.message)
        } catch let error as ConsumptionError {
            state = .failed(error.localizedDescription)
        } catch {
            print("Oväntat fel vid prisanalys: \(error)")
            state = .failed("Ett oväntat fel inträffade vid prisanalysen.")
        }
    }
}
