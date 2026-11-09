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
    private(set) var menuBarPricePerKWh: Double?
    private(set) var menuBarLabelColor: Color = DS.Color.secondary

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
    @ObservationIgnored
    private var loadGeneration = 0
    @ObservationIgnored
    private var isRefreshing = false
    @ObservationIgnored
    private var cachedToday: DayChartData?
    @ObservationIgnored
    private var cachedTomorrow: DayChartData?
    @ObservationIgnored
    private var lastPriceDayKey: String?
    @ObservationIgnored
    private var hasTomorrowPrices = false
    @ObservationIgnored
    private var lastConsumptionFetchAt: Date?
    @ObservationIgnored
    private var lastForegroundRefreshAt: Date?

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
        await loadPrices(force: true)
        guard !Task.isCancelled else { return }
        async let consumptionLoad: Void = loadConsumption()
        async let tariffLoad: Void = loadGridTariff()
        await consumptionLoad
        await tariffLoad
    }

    func refreshFromUser() async {
        await load()
    }

    func handleForeground() async {
        let now = nowProvider()
        if let lastForegroundRefreshAt, now.timeIntervalSince(lastForegroundRefreshAt) < 60 {
            applyCachedPriceDisplay(now: now)
            return
        }
        lastForegroundRefreshAt = now
        applyCachedPriceDisplay(now: now)
        if shouldRefetchPrices(now: now) {
            await loadPrices(force: false)
        }
        await loadConsumption()
    }

    func loadConsumption() async {
        let result = await consumptionLoadService.load()
        monthlyConsumption = result.monthlyConsumption ?? monthlyConsumption
        consumptionError = result.consumptionError
        powerPeaks = result.powerPeaks ?? powerPeaks
        preciseMonthlyCost = result.preciseMonthlyCost
        lastConsumptionFetchAt = nowProvider()

        if let consumption = result.monthlyConsumption {
            settings.cachedConsumption = consumption
        }
        
        await historyRecordingCoordinator.repriceStoredHistoryIfNeeded(
            priceArea: settings.priceArea,
            costProfile: settings.costProfile
        )

        if settings.isConfigured {
            await historyRecordingCoordinator.recordCurrentMonthConsumptionHistory(
                priceArea: settings.priceArea,
                providerID: settings.selectedProviderId,
                costProfile: settings.costProfile,
                quarterlyConsumption: result.quarterlyConsumption
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
        refreshTask = Task { [weak self] in
            await self?.load()
            while !Task.isCancelled {
                let now = Date()
                let nextQuarter = WidgetTimelineSchedule.nextQuarterHourUpdate(from: now)
                let delay = max(nextQuarter.timeIntervalSince(now), 0.2)
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
                if Task.isCancelled { break }
                await self?.handleQuarterHourTick()
            }
        }
    }

    private func handleQuarterHourTick() async {
        let now = nowProvider()
        applyCachedPriceDisplay(now: now)
        if shouldRefetchPrices(now: now) {
            await loadPrices(force: false)
        }
        if shouldRefetchConsumption(now: now) {
            await loadConsumption()
        }
    }

    private func loadPrices(force: Bool) async {
        loadGeneration += 1
        let myGeneration = loadGeneration
        let hasLoadedData: Bool
        if case .loaded = state {
            hasLoadedData = true
        } else {
            hasLoadedData = false
        }
        if hasLoadedData {
            isRefreshing = true
        } else {
            state = .loading
        }
        defer {
            if myGeneration == loadGeneration {
                isRefreshing = false
            }
        }

        do {
            let now = nowProvider()
            let priceArea = settings.priceArea
            let includeTomorrow = Self.isDayAheadPublished(at: now)
            let result = try await priceRefreshCoordinator.load(
                priceArea: priceArea,
                includeTomorrow: includeTomorrow,
                ignoreCache: force
            )

            guard myGeneration == loadGeneration else { return }

            cachedToday = result.payload.day
            cachedTomorrow = result.tomorrow
            hasTomorrowPrices = result.tomorrow != nil
            lastPriceDayKey = EnergyHistoryKey.dayKey(for: now)
            historyRecordingCoordinator.recordPriceHistory(dayData: result.payload.day, priceArea: priceArea)
            loadCurrentMonthHistorySummary()
            applyLoadedPrices(result.payload, now: now)
        } catch let error as DisplayableError {
            guard myGeneration == loadGeneration else { return }
            if !hasLoadedData {
                state = .failed(error.message)
            }
        } catch {
            guard myGeneration == loadGeneration else { return }
            if !hasLoadedData {
                state = .failed("Ett oväntat fel inträffade. Försök igen senare.")
            }
        }
    }

    private func applyCachedPriceDisplay(now: Date) {
        let calendar = Calendar.energyHistory
        var displayDay = cachedToday
        if let today = displayDay, let first = today.buckets.first,
           !calendar.isDate(first.start, inSameDayAs: now) {
            if let tomorrow = cachedTomorrow, let tomorrowFirst = tomorrow.buckets.first,
               calendar.isDate(tomorrowFirst.start, inSameDayAs: now) {
                displayDay = tomorrow
                cachedToday = tomorrow
                cachedTomorrow = nil
                hasTomorrowPrices = false
                lastPriceDayKey = EnergyHistoryKey.dayKey(for: now, calendar: calendar)
            } else {
                displayDay = nil
            }
        }

        guard let displayDay else { return }
        let display = priceRefreshCoordinator.displayText(from: displayDay, now: now)
        applyLoadedPrices(
            CurrentAndDay(currentDisplay: display, day: displayDay),
            now: now
        )
    }

    private func applyLoadedPrices(_ payload: CurrentAndDay, now: Date) {
        state = .loaded(payload)
        updateMenuBarDerived(from: payload.day, now: now)
    }

    private func updateMenuBarDerived(from day: DayChartData, now: Date) {
        guard let bucket = day.currentBucket(at: now) else {
            menuBarPricePerKWh = nil
            menuBarLabelColor = DS.Color.secondary
            return
        }
        menuBarPricePerKWh = TotalCostService.shared.calculatePricePerKWh(
            spotPriceOre: bucket.orePerKWh,
            profile: settings.costProfile
        )
        menuBarLabelColor = DS.Color.forPrice(bucket.orePerKWh, min: day.minOre, max: day.maxOre)
    }

    private func shouldRefetchPrices(now: Date) -> Bool {
        let todayKey = EnergyHistoryKey.dayKey(for: now)
        if lastPriceDayKey != todayKey {
            return true
        }
        return Self.isDayAheadPublished(at: now) && !hasTomorrowPrices
    }

    private func shouldRefetchConsumption(now: Date) -> Bool {
        guard let lastConsumptionFetchAt else { return true }
        return now.timeIntervalSince(lastConsumptionFetchAt) >= consumptionRefreshSeconds
    }

    private var consumptionRefreshSeconds: TimeInterval {
        let requested = TimeInterval(refreshInterval.components.seconds)
        if requested > 0 && requested < 45 * 60 {
            return max(requested, 1)
        }
        return 45 * 60
    }

    private static func isDayAheadPublished(at date: Date, calendar: Calendar = .energyHistory) -> Bool {
        date >= WidgetTimelineSchedule.nextDayAheadRefresh(
            from: calendar.startOfDay(for: date),
            calendar: calendar
        )
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

    func load(priceArea: String, includeTomorrow: Bool, ignoreCache: Bool) async throws -> PriceLoadResult {
        let now = nowProvider()
        let items = try await service.fetchSpotPrices(for: now, area: priceArea, ignoreCache: ignoreCache)
        let currentDisplay = try service.makeDisplayText(
            from: items,
            now: now,
            formatter: numberFormatter
        )
        let dayData = try service.makeDayChartData(from: items, for: now)
        var tomorrow: DayChartData?
        if includeTomorrow {
            let calendar = Calendar.energyHistory
            if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                tomorrow = await service.cachedOrFetchedDayChart(for: tomorrowDate, area: priceArea)
            }
        }

        return PriceLoadResult(
            payload: SpotPriceViewModel.CurrentAndDay(currentDisplay: currentDisplay, day: dayData),
            tomorrow: tomorrow
        )
    }

    func displayText(from day: DayChartData, now: Date) -> String {
        guard let bucket = day.currentBucket(at: now) else {
            return "--"
        }
        return numberFormatter.string(from: NSNumber(value: bucket.orePerKWh))
            ?? String(format: "%.1f", bucket.orePerKWh)
    }
}

private struct PriceLoadResult {
    let payload: SpotPriceViewModel.CurrentAndDay
    let tomorrow: DayChartData?
}

private struct ConsumptionLoadResult {
    let monthlyConsumption: ConsumptionData?
    let powerPeaks: [PowerPeak]?
    let preciseMonthlyCost: PreciseMonthlyCost?
    let quarterlyConsumption: [QuarterlyConsumption]?
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
        let quarterly = await loadQuarterlyConsumption()

        let powerPeaks: [PowerPeak]?
        let preciseMonthlyCost: PreciseMonthlyCost?
        if let quarterly, !quarterly.isEmpty {
            powerPeaks = consumptionService.powerPeaks(fromQuarterly: quarterly)
            do {
                let cost = try await consumptionService.calculatePreciseMonthlyCost(
                    from: quarterly,
                    spotPriceService: spotPriceService
                )
                preciseMonthlyCost = cost
                AppLog.viewModel.info("Precise cost loaded: \(cost.totalCostKr, privacy: .public) kr")
            } catch {
                AppLog.viewModel.notice("Precise cost unavailable: \(error.localizedDescription, privacy: .public)")
                preciseMonthlyCost = nil
            }
        } else {
            powerPeaks = await loadPowerPeaks()
            preciseMonthlyCost = await loadPreciseMonthlyCost()
        }

        let consumptionResult = await consumption
        return ConsumptionLoadResult(
            monthlyConsumption: consumptionResult.monthlyConsumption,
            powerPeaks: powerPeaks,
            preciseMonthlyCost: preciseMonthlyCost,
            quarterlyConsumption: quarterly,
            consumptionError: consumptionResult.errorMessage
        )
    }

    private func loadQuarterlyConsumption() async -> [QuarterlyConsumption]? {
        let calendar = Calendar.energyHistory
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return nil
        }
        do {
            let quarterly = try await consumptionService.fetchQuarterlyConsumption(startDate: monthStart, endDate: now)
            return quarterly.isEmpty ? nil : quarterly
        } catch {
            AppLog.viewModel.notice("Quarterly consumption unavailable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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

    func repriceStoredHistoryIfNeeded(priceArea: String, costProfile: CostProfile) async {
        await historyRecorder?.repriceStoredHistoryIfNeeded(
            spotPriceService: spotPriceService,
            priceArea: priceArea,
            costProfile: costProfile
        )
    }

    func recordCurrentMonthConsumptionHistory(
        priceArea: String,
        providerID: String,
        costProfile: CostProfile,
        quarterlyConsumption: [QuarterlyConsumption]?
    ) async {
        await historyRecorder?.recordCurrentMonthConsumptionHistory(
            consumptionService: consumptionService,
            spotPriceService: spotPriceService,
            priceArea: priceArea,
            providerID: providerID,
            costProfile: costProfile,
            now: nowProvider(),
            quarterlyConsumption: quarterlyConsumption
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
