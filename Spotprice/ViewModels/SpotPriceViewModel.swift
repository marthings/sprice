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
    private(set) var powerPeaks: [PowerPeak] = []
    private(set) var preciseMonthlyCost: PreciseMonthlyCost?
    private(set) var consumptionError: String?
    private(set) var currentTariff: SimplifiedTariff?

    private let service: SpotPriceService
    private let consumptionService: ConsumptionService
    private let gridTariffService: GridTariffService
    private let settings: ConsumptionSettings
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
    // Generation counter – stale loads discard their results
    private var loadGeneration = 0

    init(
        service: SpotPriceService? = nil,
        consumptionService: ConsumptionService? = nil,
        gridTariffService: GridTariffService? = nil,
        settings: ConsumptionSettings? = nil,
        numberFormatter: NumberFormatter? = nil,
        now: @escaping () -> Date = { Date.now },
        refreshInterval: Duration = .seconds(900)
    ) {
        self.service = service ?? SpotPriceService()
        self.consumptionService = consumptionService ?? ConsumptionService()
        self.gridTariffService = gridTariffService ?? GridTariffService()
        self.settings = settings ?? .shared
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
        // Bump generation so any in-flight load discards its stale results
        loadGeneration += 1
        let myGeneration = loadGeneration
        state = .loading

        do {
            let now = nowProvider()
            let items = try await service.fetchSpotPrices(for: now)

            // Superseded by a newer load – discard
            guard myGeneration == loadGeneration else { return }

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
            guard myGeneration == loadGeneration else { return }
            state = .failed(error.message)
        } catch {
            guard myGeneration == loadGeneration else { return }
            state = .failed("Ett oväntat fel inträffade. Försök igen senare.")
        }

        // Also load consumption and tariff (don't block on errors)
        guard myGeneration == loadGeneration else { return }
        async let consumptionLoad: Void = loadConsumption()
        async let tariffLoad: Void = loadGridTariff()
        
        await consumptionLoad
        await tariffLoad
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
            
            // Cache consumption data for widget access
            if let consumption = monthlyConsumption {
                settings.cachedConsumption = consumption
            }

            print("📊 ViewModel: Consumption loaded - \(monthlyConsumption?.totalKWh ?? 0) kWh, \(dailyConsumption.count) daily values")
        } catch {
            consumptionError = error.localizedDescription
            print("📊 ViewModel: Consumption error - \(error.localizedDescription)")
            // Don't clear existing data on error
        }

        // Calculate power peaks (non-blocking, best-effort)
        do {
            powerPeaks = try await consumptionService.calculatePowerPeaks()
            print("📊 ViewModel: Power peaks = \(powerPeaks.count)")
        } catch {
            print("📊 ViewModel: Power peaks unavailable - \(error.localizedDescription)")
        }

        // Calculate precise monthly cost (non-blocking, best-effort)
        do {
            preciseMonthlyCost = try await consumptionService.calculatePreciseMonthlyCost(spotPriceService: service)
            print("📊 ViewModel: Precise cost = \(String(format: "%.2f", preciseMonthlyCost?.totalCostKr ?? 0)) kr")
        } catch {
            print("📊 ViewModel: Precise cost unavailable - \(error.localizedDescription)")
            // Keep preciseMonthlyCost as nil — UI falls back to estimated
        }
    }
    
    func loadGridTariff() async {
        let dsoOrgNo = settings.selectedDSOOrgNo
        
        guard !dsoOrgNo.isEmpty else {
            currentTariff = nil
            return
        }
        
        // Try cache first
        if let cached = settings.cachedTariff {
            currentTariff = cached
            print("📊 ViewModel: Using cached tariff for \(cached.dsoName)")
            return
        }
        
        // Fetch from API with current fuse size
        do {
            let tariff = try await gridTariffService.fetchTariff(forDSO: dsoOrgNo, fuseSize: settings.fuseSize)
            currentTariff = tariff
            settings.cachedTariff = tariff
            if let tariff = tariff {
                print("📊 ViewModel: Loaded tariff for \(tariff.dsoName) @ \(tariff.fuseSize ?? 0)A")
            }
        } catch {
            // Non-fatal - just log and continue without tariff
            print("📊 ViewModel: Failed to load grid tariff: \(error)")
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
