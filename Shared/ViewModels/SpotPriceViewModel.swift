//
//  SpotPriceViewModel.swift
//  Spotprice
//
//  Created by Martin Berggren on 2026-01-25.
//
import SwiftUI
import OSLog

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
    private(set) var powerPeaks: [PowerPeak] = []
    private(set) var preciseMonthlyCost: PreciseMonthlyCost?
    private(set) var consumptionError: String?
    private(set) var currentTariff: SimplifiedTariff?
    private(set) var currentMonthHistorySummary: HistoricalEnergySummaryValue?

    private let priceRefreshCoordinator: SpotPriceRefreshCoordinator
    private let consumptionLoadService: ConsumptionLoadService
    private let historyRecordingCoordinator: HistoryRecordingCoordinator
    private let gridTariffService: GridTariffService
    private let settings: ConsumptionSettings
    private let nowProvider: () -> Date

    // Periodisk uppdaterings-Task
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    // Konfigurerbart intervall (default 15 min)
    private let refreshInterval: Duration
    // Task för settings-notifikation
    @ObservationIgnored
    private var settingsRefreshTask: Task<Void, Never>?
    // Generation counter – stale loads discard their results
    private var loadGeneration = 0

    init(
        service: SpotPriceService? = nil,
        consumptionService: ConsumptionService? = nil,
        gridTariffService: GridTariffService? = nil,
        historyRecorder: EnergyHistoryRecorder? = nil,
        historyQuery: (any EnergyHistoryQuerying)? = nil,
        settings: ConsumptionSettings? = nil,
        numberFormatter: NumberFormatter? = nil,
        now: @escaping () -> Date = { Date.now },
        refreshInterval: Duration = .seconds(900)
    ) {
        let resolvedSpotPriceService = service ?? SpotPriceService()
        let resolvedConsumptionService = consumptionService ?? ConsumptionService()
        let resolvedHistoryRecorder = historyRecorder ?? (try? EnergyHistoryRecorder())

        self.priceRefreshCoordinator = SpotPriceRefreshCoordinator(
            service: resolvedSpotPriceService,
            numberFormatter: numberFormatter ?? AppFormatters.decimalNumberFormatter(maximumFractionDigits: 1),
            nowProvider: now
        )
        self.consumptionLoadService = ConsumptionLoadService(
            consumptionService: resolvedConsumptionService,
            spotPriceService: resolvedSpotPriceService
        )
        self.historyRecordingCoordinator = HistoryRecordingCoordinator(
            historyRecorder: resolvedHistoryRecorder,
            historyQuery: historyQuery ?? EnergyHistoryQueryService(),
            consumptionService: resolvedConsumptionService,
            spotPriceService: resolvedSpotPriceService,
            nowProvider: now
        )
        self.gridTariffService = gridTariffService ?? GridTariffService()
        self.settings = settings ?? .shared
        self.nowProvider = now
        self.refreshInterval = refreshInterval

        // Starta periodisk uppdatering direkt
        startPeriodicRefresh()

        // Lyssna på settings-ändringar (ladda om både priser och förbrukning)
        observeSettingsChanges()
    }

    deinit {
        refreshTask?.cancel()
        settingsRefreshTask?.cancel()
    }
    
    func load() async {
        // Bump generation so any in-flight load discards its stale results
        loadGeneration += 1
        let myGeneration = loadGeneration
        state = .loading

        do {
            let priceArea = settings.priceArea
            let payload = try await priceRefreshCoordinator.load(priceArea: priceArea)

            // Superseded by a newer load – discard
            guard myGeneration == loadGeneration else { return }

            historyRecordingCoordinator.recordPriceHistory(dayData: payload.day, priceArea: priceArea)
            loadCurrentMonthHistorySummary()

            state = .loaded(payload)
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
        let result = await consumptionLoadService.load()
        monthlyConsumption = result.monthlyConsumption ?? monthlyConsumption
        consumptionError = result.consumptionError
        powerPeaks = result.powerPeaks ?? powerPeaks
        preciseMonthlyCost = result.preciseMonthlyCost

        if let consumption = result.monthlyConsumption {
            settings.cachedConsumption = consumption
        }
        
        if settings.isConfigured {
            await historyRecordingCoordinator.recordCurrentMonthConsumptionHistory(
                priceArea: settings.priceArea,
                providerID: settings.selectedProviderId,
                costProfile: settings.costProfile
            )
            historyRecordingCoordinator.startPastMonthBackfill(
                priceArea: settings.priceArea,
                providerID: settings.selectedProviderId,
                costProfile: settings.costProfile
            )
        }

        loadCurrentMonthHistorySummary()
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
            return
        }
        
        // Fetch from API with current fuse size
        do {
            let tariff = try await gridTariffService.fetchTariff(forDSO: dsoOrgNo, fuseSize: settings.fuseSize)
            currentTariff = tariff
            settings.cachedTariff = tariff
            if let tariff = tariff {
                AppLog.viewModel.info("Loaded tariff for \(tariff.dsoName, privacy: .public) at \(tariff.fuseSize ?? 0)A")
            }
        } catch {
            // Non-fatal - just log and continue without tariff
            AppLog.viewModel.error("Failed to load grid tariff: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Periodisk uppdatering
    
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        let interval = refreshInterval
        refreshTask = Task { [weak self] in
            // Kör en initial laddning direkt
            await self?.load()
            // Kör därefter var 15:e minut tills Task avbryts
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    // Avbruten sömn -> avsluta loopen
                    break
                }
                if Task.isCancelled { break }
                await self?.load()
            }
        }
    }

    private func observeSettingsChanges() {
        settingsRefreshTask?.cancel()
        settingsRefreshTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(named: .consumptionSettingsDidSave)
            for await _ in notifications {
                if Task.isCancelled { break }
                await self?.load()
            }
        }
    }

    private func loadCurrentMonthHistorySummary() {
        do {
            let monthKey = EnergyHistoryKey.monthKey(for: nowProvider())
            currentMonthHistorySummary = try historyRecordingCoordinator.loadCurrentMonthSummary(
                priceArea: settings.priceArea,
                monthKey: monthKey
            )
        } catch {
            AppLog.history.error("Failed to load current month summary: \(error.localizedDescription, privacy: .public)")
        }
    }
}

@MainActor
private final class SpotPriceRefreshCoordinator {
    private let service: SpotPriceService
    private let numberFormatter: NumberFormatter
    private let nowProvider: () -> Date

    init(
        service: SpotPriceService,
        numberFormatter: NumberFormatter,
        nowProvider: @escaping () -> Date
    ) {
        self.service = service
        self.numberFormatter = numberFormatter
        self.nowProvider = nowProvider
    }

    func load(priceArea: String) async throws -> SpotPriceViewModel.CurrentAndDay {
        let now = nowProvider()
        let items = try await service.fetchSpotPrices(for: now, area: priceArea)
        let currentDisplay = try service.makeDisplayText(
            from: items,
            now: now,
            formatter: numberFormatter
        )
        let dayData = try service.makeDayChartData(from: items, for: now)

        return SpotPriceViewModel.CurrentAndDay(currentDisplay: currentDisplay, day: dayData)
    }
}

private struct ConsumptionLoadResult {
    let monthlyConsumption: ConsumptionData?
    let powerPeaks: [PowerPeak]?
    let preciseMonthlyCost: PreciseMonthlyCost?
    let consumptionError: String?
}

@MainActor
private final class ConsumptionLoadService {
    private let consumptionService: ConsumptionService
    private let spotPriceService: SpotPriceService

    init(
        consumptionService: ConsumptionService,
        spotPriceService: SpotPriceService
    ) {
        self.consumptionService = consumptionService
        self.spotPriceService = spotPriceService
    }

    func load() async -> ConsumptionLoadResult {
        async let consumption = loadConsumption()
        async let powerPeaks = loadPowerPeaks()
        async let preciseMonthlyCost = loadPreciseMonthlyCost()

        let consumptionResult = await consumption
        return ConsumptionLoadResult(
            monthlyConsumption: consumptionResult.monthlyConsumption,
            powerPeaks: await powerPeaks,
            preciseMonthlyCost: await preciseMonthlyCost,
            consumptionError: consumptionResult.errorMessage
        )
    }

    private func loadConsumption() async -> (
        monthlyConsumption: ConsumptionData?,
        errorMessage: String?
    ) {
        do {
            let monthlyConsumption = try await consumptionService.fetchCurrentMonthConsumption()
            AppLog.viewModel.info("Consumption loaded: \(monthlyConsumption.totalKWh, privacy: .public) kWh")
            return (monthlyConsumption, nil)
        } catch {
            AppLog.viewModel.error("Consumption error: \(error.localizedDescription, privacy: .public)")
            return (nil, error.userFacingMessage)
        }
    }

    private func loadPowerPeaks() async -> [PowerPeak]? {
        do {
            let powerPeaks = try await consumptionService.calculatePowerPeaks()
            AppLog.viewModel.info("Power peaks loaded: \(powerPeaks.count)")
            return powerPeaks
        } catch {
            AppLog.viewModel.notice("Power peaks unavailable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func loadPreciseMonthlyCost() async -> PreciseMonthlyCost? {
        do {
            let preciseMonthlyCost = try await consumptionService.calculatePreciseMonthlyCost(spotPriceService: spotPriceService)
            AppLog.viewModel.info("Precise cost loaded: \(preciseMonthlyCost.totalCostKr, privacy: .public) kr")
            return preciseMonthlyCost
        } catch {
            AppLog.viewModel.notice("Precise cost unavailable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

@MainActor
private final class HistoryRecordingCoordinator {
    private let historyRecorder: EnergyHistoryRecorder?
    private let historyQuery: any EnergyHistoryQuerying
    private let consumptionService: ConsumptionService
    private let spotPriceService: SpotPriceService
    private let nowProvider: () -> Date

    init(
        historyRecorder: EnergyHistoryRecorder?,
        historyQuery: any EnergyHistoryQuerying,
        consumptionService: ConsumptionService,
        spotPriceService: SpotPriceService,
        nowProvider: @escaping () -> Date
    ) {
        self.historyRecorder = historyRecorder
        self.historyQuery = historyQuery
        self.consumptionService = consumptionService
        self.spotPriceService = spotPriceService
        self.nowProvider = nowProvider
    }

    func recordPriceHistory(dayData: DayChartData, priceArea: String) {
        historyRecorder?.recordPriceHistory(dayData: dayData, priceArea: priceArea)
    }

    func recordCurrentMonthConsumptionHistory(
        priceArea: String,
        providerID: String,
        costProfile: CostProfile
    ) async {
        await historyRecorder?.recordCurrentMonthConsumptionHistory(
            consumptionService: consumptionService,
            spotPriceService: spotPriceService,
            priceArea: priceArea,
            providerID: providerID,
            costProfile: costProfile,
            now: nowProvider()
        )
    }

    func startPastMonthBackfill(
        priceArea: String,
        providerID: String,
        costProfile: CostProfile
    ) {
        let recorder = historyRecorder
        let consumptionService = consumptionService
        let spotPriceService = spotPriceService
        let now = nowProvider()
        Task {
            await EnergyHistoryBackfillController.shared.runIfNeeded(
                recorder: recorder,
                consumptionService: consumptionService,
                spotPriceService: spotPriceService,
                priceArea: priceArea,
                providerID: providerID,
                costProfile: costProfile,
                now: now
            )
        }
    }

    func loadCurrentMonthSummary(priceArea: String?, monthKey: String) throws -> HistoricalEnergySummaryValue? {
        try historyQuery.loadCurrentMonthSummary(priceArea: priceArea, monthKey: monthKey)
    }
}
