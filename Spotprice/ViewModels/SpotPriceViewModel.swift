//
//  SpotPriceViewModel.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-25.
//
import SwiftUI
import Combine

@Observable @MainActor
final class SpotPriceViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(CurrentAndDay)  // carries current display text and chart-ready day data
        case failed(String)
    }

    struct CurrentAndDay: Equatable {
        let currentDisplay: String
        let day: DayChartData
    }

    private(set) var state: State = .idle
    private(set) var monthlyConsumption: ConsumptionData?
    private(set) var dailyConsumption: [DailyConsumption] = []
    private(set) var consumptionError: String?

    private let service: SpotPriceService
    private let consumptionService: ConsumptionService
    private let numberFormatter: NumberFormatter
    private let nowProvider: () -> Date

    // Periodisk uppdaterings-Task
    @ObservationIgnored
    nonisolated(unsafe) private var refreshTask: Task<Void, Never>?
    // Konfigurerbart intervall (default 15 min)
    private let refreshInterval: Duration
    // Subscription för settings-notifikation
    @ObservationIgnored
    nonisolated(unsafe) private var settingsSubscription: AnyCancellable?

    init(
        service: SpotPriceService? = nil,
        consumptionService: ConsumptionService? = nil,
        numberFormatter: NumberFormatter? = nil,
        now: @escaping () -> Date = { Date() },
        refreshInterval: Duration = .seconds(900)
    ) {
        self.service = service ?? SpotPriceService()
        self.consumptionService = consumptionService ?? ConsumptionService()
        self.numberFormatter = numberFormatter ?? {
            let formatter = NumberFormatter()
            formatter.locale = .current
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            return formatter
        }()
        self.nowProvider = now
        self.refreshInterval = refreshInterval

        // Starta periodisk uppdatering direkt
        startPeriodicRefresh()

        // Lyssna på settings-ändringar (ladda om både priser och förbrukning)
        settingsSubscription = NotificationCenter.default
            .publisher(for: .consumptionSettingsDidSave)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.load()
                }
            }
    }

    deinit {
        refreshTask?.cancel()
        settingsSubscription?.cancel()
    }
    
    func load() async {
        // Avoid redundant loads
        if case .loading = state { return }
        state = .loading

        do {
            let now = nowProvider()
            let items = try await service.fetchSpotPrices(for: now)

            // Build current display text
            let currentDisplay = try service.makeDisplayText(
                from: items,
                now: now,
                formatter: numberFormatter
            )

            // Build chart-ready day data
            let dayData = try service.makeDayChartData(from: items, for: now)

            state = .loaded(CurrentAndDay(currentDisplay: currentDisplay, day: dayData))
        } catch let error as DisplayableError {
            state = .failed(error.message)
        } catch {
            state = .failed("Ett oväntat fel inträffade. Försök igen senare.")
        }

        // Also load consumption (don't block on errors)
        await loadConsumption()
    }

    func loadConsumption() async {
        do {
            print("📊 ViewModel: Loading consumption...")

            // Fetch monthly and daily data in parallel
            async let monthlyData = consumptionService.fetchCurrentMonthConsumption()
            async let dailyData = consumptionService.fetchCurrentMonthDailyConsumption()

            monthlyConsumption = try await monthlyData
            dailyConsumption = (try? await dailyData) ?? []
            consumptionError = nil

            print("📊 ViewModel: Consumption loaded - \(monthlyConsumption?.totalKWh ?? 0) kWh, \(dailyConsumption.count) daily values")
        } catch {
            consumptionError = error.localizedDescription
            print("📊 ViewModel: Consumption error - \(error.localizedDescription)")
            // Don't clear existing data on error
        }
    }
    
    // MARK: - Periodisk uppdatering
    
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            // Kör en initial laddning direkt
            await self.load()
            // Kör därefter var 15:e minut tills Task avbryts
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: self.refreshInterval)
                } catch {
                    // Avbruten sömn -> avsluta loopen
                    break
                }
                if Task.isCancelled { break }
                await self.load()
            }
        }
    }
}
