# DX And DRY Refactor Sprints

Goal: improve developer experience, reduce repeated code, and make Sprice easier to ship and maintain without changing product behavior unnecessarily.

This is a refactor track, not a redesign track. Each sprint should be small enough to review, build, and verify independently.

## Product And Engineering Principles

- Keep behavior stable unless the sprint explicitly says otherwise.
- Prefer shared helpers for formatting, logging, data selection, and repeated UI states.
- Avoid broad rewrites of working UI. Extract only where it reduces real duplication or improves testability.
- Keep platform boundaries clear:
  - `Shared`: models, services, formatters, logging, platform-neutral SwiftUI components.
  - `Spotprice`: macOS menu bar shell and macOS-specific interactions.
  - `SpotpriceApp`: iOS shell and iOS-specific navigation.
  - `SpotpriceWidget`: widget-specific presentation only.
- Every sprint must end with Xcode diagnostics on changed files and a full project build.

## Current Refactor Baseline

Already done:

- [x] Replaced `print` calls with categorized `Logger` usage through `AppLog`.
- [x] Centralized historical coverage labels, colors, and text styles.
- [x] Centralized historical summary quality ranking and best-summary selection.
- [x] Fixed current-month history summary selection to prefer measured/partial data over price-only data.
- [x] Added `vat_cost_sek` to history CSV export.
- [x] Removed hardcoded chart hit-test width from the history chart.
- [x] Centralized Swedish locale, Europe/Stockholm timezone, energy calendar, common date labels, CSV number formatting, and shared display number formatter.

Known remaining hotspots:

- `SpotPriceViewModel` owns too much orchestration: price loading, consumption, tariff, history recording, settings observation, and periodic refresh.
- Widget monthly-cost fallback logic duplicates app cost logic.

## Sprint 1: Shared Locale, Calendar, And Formatters

### Goal

Make Swedish locale/timezone/date formatting consistent and easy to reuse.

### Scope

- Add a shared formatter utility:
  - `AppFormatters` in `Shared/DesignSystem/DesignSystem.swift`
- Centralize:
  - Swedish locale.
  - Europe/Stockholm timezone.
  - Gregorian energy calendar.
  - Common date labels: month, day, weekday/day/month, power peak date, widget month label.
  - Common POSIX number formatting used for CSV.
- Replace local `DateFormatter()` and repeated `Locale(identifier: "sv_SE")` where it is purely presentation.
- Keep provider API date formatting explicit when the remote API requires a precise format.

### Candidate Files

- `Shared/Models/ConsumptionModels.swift`
- `Shared/Models/HistoricalEnergyModels.swift`
- `Shared/Services/SpotPriceService.swift`
- `Shared/Services/ConsumptionService.swift`
- `Shared/Services/EnergyHistoryStore.swift`
- `Spotprice/Views/TopConsumptionDaysCard.swift`
- `SpotpriceApp/MonthlyConsumptionSection.swift`
- `SpotpriceApp/HistoryMonthView.swift`
- `SpotpriceWidget/SpotpriceWidget.swift`

### Acceptance Criteria

- [x] No repeated `Locale(identifier: "sv_SE")` outside the formatter utility unless there is a clear API-specific reason.
- [x] No repeated `TimeZone(identifier: "Europe/Stockholm")` outside shared calendar/formatter setup unless API-specific.
- [x] Date labels remain unchanged in app, menu bar, and widget.
- [x] Project builds.

### Out Of Scope

- Do not change date storage keys or historical deduplication behavior.
- Do not alter provider API request formats unless covered by tests or manual verification.

## Sprint 2: Privacy-Safe Provider Logging

### Goal

Keep diagnostics useful without logging provider payloads, queries, credentials, account identifiers, or raw responses.

### Scope

- Audit provider logging in:
  - `TibberProvider`
  - `VaggerydProvider`
  - `ConsumptionService`
  - `SpotPriceService`
- Replace raw payload/query logs with safe metadata:
  - HTTP status code.
  - Endpoint kind, not full URL when URL contains identifiers.
  - Response byte count.
  - Decoded item counts.
  - Error type and localized message when safe.
- Use privacy annotations intentionally:
  - `.private` for anything user/account/provider-specific.
  - `.public` only for generic status, counts, and non-sensitive app state.

### Acceptance Criteria

- [x] No raw Tibber GraphQL query or raw response body is logged.
- [x] No Vaggeryd URLs containing account/customer IDs are logged as public text.
- [x] Provider logs still identify which operation failed.
- [x] Xcode diagnostics and project build pass.

### Out Of Scope

- Do not change provider request behavior.
- Do not redesign provider error handling beyond logging hygiene.

## Sprint 3: Shared Status And Empty-State Components

### Goal

Reduce repeated status/error/loading row UI while keeping platform-specific actions intact.

### Scope

- Add shared components under `Shared/Components`, for example:
  - `StatusRow`
  - `StatusCard`
  - `EmptyStateCard`
- Support:
  - icon
  - title
  - message
  - semantic color
  - optional trailing icon
  - optional action wrapper supplied by caller
- Replace repeated status rows in:
  - `DashboardTabSupport`
  - `MonthlyConsumptionSection`
  - `MonthlyStatsSection`
  - `HistoryMonthView`
  - relevant settings sections if low risk

### Acceptance Criteria

- [x] Repeated status row layout exists in one shared component.
- [x] Existing strings and actions remain unchanged.
- [x] macOS menu bar and iOS app both build.

### Out Of Scope

- Do not redesign card styling.
- Do not change settings flows.

## Sprint 4: History View Decomposition

### Goal

Make `HistoryMonthView` smaller, previewable, and easier to maintain.

### Scope

Extract platform-neutral subviews:

- `HistoryMonthSummaryCards`
- `HistoryTopDaysSection`
- `HistoryDailyChart`
- `HistoryDailyTable`
- `HistoryDayCalloutView`

Keep `HistoryMonthView` responsible for:

- selected month state
- view mode state
- loading history data
- composing extracted subviews

### Acceptance Criteria

- [x] `HistoryMonthView` is mostly orchestration and composition.
- [x] Extracted subviews are covered by loaded, empty, measured, and mixed mock previews through injected view state.
- [x] Chart selection behavior remains unchanged.
- [x] Project builds.

### Out Of Scope

- Do not change SwiftData queries in this sprint.
- Do not introduce a new data provider abstraction yet.

## Sprint 5: Testable History Loading

### Goal

Remove direct SwiftData construction from UI and make history loading easy to preview and test.

### Scope

- Add a small query abstraction, suggested:
  - `EnergyHistoryQuerying`
  - `EnergyHistoryQueryService`
- Responsibilities:
  - fetch monthly summaries
  - fetch daily summaries for selected month
  - fetch top cost days
  - fetch top consumption days
  - choose best summary per period
- Inject this into `HistoryMonthView` and `SpotPriceViewModel` where appropriate.
- Add in-memory/mock implementation for previews.

### Acceptance Criteria

- [x] `HistoryMonthView` does not instantiate `SwiftDataEnergyHistoryStore` directly.
- [x] `SpotPriceViewModel` does not duplicate best-summary selection logic.
- [x] Previews can render loaded, empty, and failed history states without SwiftData setup.
- [x] Project builds.

### Out Of Scope

- Do not migrate stored data.
- Do not add CloudKit or sync behavior.

## Sprint 6: ViewModel Orchestration Split

### Goal

Reduce `SpotPriceViewModel` responsibilities and make refresh behavior easier to reason about.

### Scope

Introduce small collaborators:

- `SpotPriceRefreshCoordinator`
  - fetches prices
  - builds display/chart data
  - keeps price loading separate from observable state updates
- `ConsumptionLoadService`
  - loads monthly consumption
  - loads daily consumption
  - calculates power peaks
  - calculates precise monthly cost
- `HistoryRecordingCoordinator`
  - records price history
  - records current-month consumption history
  - loads current-month summary

`SpotPriceViewModel` should remain the observable UI state owner.

### Acceptance Criteria

- [x] `SpotPriceViewModel.load()` reads like orchestration, not implementation detail.
- [x] Consumption loading can be tested separately from price loading.
- [x] History recording can fail without taking down price display.
- [x] Project builds.

### Out Of Scope

- Do not change UI states unless needed to preserve current behavior.
- Do not add persistence changes.

## Sprint 7: Shared Monthly Cost Estimation

### Goal

Make app and widget use the same monthly cost fallback logic.

### Scope

- Add a shared helper, suggested:
  - `MonthlyCostEstimator`
- Move widget fallback logic out of `SpotpriceWidget.swift`.
- Ensure the helper can handle:
  - history cost available
  - cached consumption available
  - no consumption available
  - fixed monthly fees
  - average day price fallback

### Acceptance Criteria

- [x] Widget no longer owns monthly cost math.
- [x] App and widget can share the same estimation logic.
- [x] Existing widget display remains unchanged.
- [x] Project builds.

### Out Of Scope

- Do not add network calls to the widget.
- Do not change widget timeline policy.

## Sprint 8: Shared Components Inventory And Target Boundaries

### Goal

Make it obvious which UI components are shared, macOS-only, iOS-only, or widget-only.

### Scope

- Audit duplicated app/menu bar components:
  - chart callouts
  - cost cards
  - stats cards
  - monthly consumption sections
- Move platform-neutral components into `Shared/Components` only when they compile for all intended targets.
- Add short file headers or docs where a component is intentionally platform-specific.

### Inventory Notes

- `Shared/Components/ChartCalloutView.swift` remains the shared/macOS menu bar callout used by `SpotPriceBarChart`.
- `SpotpriceApp/ChartCalloutView.swift` is intentionally iOS-specific and the type is named `IOSChartCalloutView` to avoid same-name target ambiguity.
- `MonthlyCostCard`, `CostBreakdownRow`, and `CostBreakdownSubRow` are macOS menu bar components today; they depend on that layout density and should not move until iOS needs the same full breakdown surface.
- `MonthlyStatsSection` and `MonthlyConsumptionSection` share data concepts but not layout responsibility. Keep separate unless a future sprint extracts smaller neutral subcomponents.
- Widget chart pieces stay widget-local because they depend on `WidgetKit` rendering modes and timeline constraints.

### Acceptance Criteria

- [x] Shared UI has clear target membership.
- [x] Duplicate components are either unified or explicitly documented as platform-specific.
- [x] Project builds all targets.

### Out Of Scope

- Do not chase every minor visual difference.
- Do not move components that depend on platform-only APIs without wrappers.

## Sprint 8.5: Small Shared Component And Presenter Cleanup

### Goal

Remove remaining low-risk UI and presenter duplication before adding tests.

### Scope

- Add shared `MetricCard` for repeated icon/title/value/unit cards.
- Add `PriceBucketAnalytics.averageSpotPrice(_:)` for shared price bucket calculations.
- Add `CostBreakdownPresenter` for chart callout cost breakdown components.
- Replace obvious local duplicates in:
  - history month summary cards
  - iOS monthly consumption cards
  - macOS stat cards
  - app/menu bar cost examples and price range sections
  - iOS/macOS chart callouts

### Acceptance Criteria

- [x] Repeated average spot price helpers are removed.
- [x] Chart callout breakdown selection is shared.
- [x] At least two repeated metric-card layouts use `MetricCard`.
- [x] Project builds.

### Out Of Scope

- Do not redesign card visuals.
- Do not merge full iOS/macOS monthly sections.

## Sprint 8.6: Shared Formatting And History UI Polish

### Goal

Centralize recurring unit formatting and small history UI fragments before moving into test coverage.

### Scope

- Add shared `AppFormatters` helpers for common display units:
  - whole kronor
  - kronor per kWh
  - kWh
  - öre
  - unitless rounded values used by split value/unit UI.
- Add `HistoryCoverageBadge` for repeated historical coverage capsules.
- Add `CostPrecisionNote` for repeated precise-cost coverage text.
- Replace obvious duplicates in:
  - iOS monthly consumption section
  - macOS monthly stats section
  - macOS menu bar historical summary
  - iOS history month summary and callout values.

### Acceptance Criteria

- [x] Coverage badges use one shared view.
- [x] Precise cost note uses one shared view.
- [x] Common unit formatting has shared helpers.
- [x] Project builds.

### Out Of Scope

- Do not redesign history or cost sections.
- Do not convert every numeric `Text(..., format:)` call where SwiftUI formatting is clearer locally.

## Sprint 8.7: Shared Cost Rows And Consumption Card Cleanup

### Goal

Make cost breakdown rows and remaining consumption stat cards use shared component primitives.

### Scope

- Add shared cost breakdown row components:
  - `SharedCostBreakdownRow`
  - `SharedCostBreakdownSubRow`
- Keep existing macOS `CostBreakdownRow` and `CostBreakdownSubRow` as thin wrappers to avoid target membership churn.
- Replace iOS monthly consumption cost rows with `SharedCostBreakdownRow`.
- Let `ConsumptionStatCard` reuse `MetricCard` while preserving subtitle support.

### Acceptance Criteria

- [x] iOS and macOS cost breakdown rows share row primitives.
- [x] Existing macOS cost card call sites keep working.
- [x] `ConsumptionStatCard` uses shared metric-card structure.
- [x] Project builds.

### Out Of Scope

- Do not merge full cost cards between platforms.
- Do not remove wrapper files from the Xcode project in this sprint.

## Sprint 8.8: Feature View Folders

### Goal

Make each app target easier to navigate by grouping views by feature inside that app, without sharing or merging views between apps.

### Scope

- Add feature folders in `SpotpriceApp`:
  - `App`
  - `Dashboard`
  - `DailyPrice`
  - `Cost`
  - `Consumption`
  - `History`
  - `Settings`
- Add feature folders in `Spotprice/Views`:
  - `MenuBar`
  - `Cost`
  - `Consumption`
  - `Settings`
- Move only view/app-shell files.
- Keep assets, `Info.plist`, and entitlements at the target root.
- Keep `Shared` structure unchanged in this sprint.

### Acceptance Criteria

- [x] iOS app views are grouped by feature.
- [x] macOS menu bar views are grouped by feature.
- [x] No view behavior or type names changed.
- [x] Project builds.

### Out Of Scope

- Do not share views between app targets.
- Do not reorganize `Shared` model, service, or component folders in this sprint.

## Sprint 9: Lightweight Test Coverage

### Goal

Add targeted tests around refactored logic so future cleanup is less risky.

### Scope

Candidate tests:

- `HistoricalEnergySummaryValue.isPreferred(over:)`
- best summary selection by month/day
- coverage text variants
- formatter outputs for Swedish dates
- monthly cost estimator scenarios
- provider log redaction helpers if introduced

### Acceptance Criteria

- [ ] Tests cover shared pure logic introduced in previous sprints.
- [ ] Tests do not require live provider credentials or network.
- [ ] Full test/build path is documented.

### Out Of Scope

- Do not create brittle SwiftUI snapshot tests in this sprint.
- Do not hit real provider APIs.

## Suggested Execution Order

1. Sprint 1: Shared locale/calendar/formatters.
2. Sprint 2: Privacy-safe provider logging.
3. Sprint 3: Shared status components.
4. Sprint 4: History view decomposition.
5. Sprint 5: Testable history loading.
6. Sprint 6: ViewModel orchestration split.
7. Sprint 7: Shared monthly cost estimation.
8. Sprint 8: Shared components inventory.
9. Sprint 8.5: Small shared component and presenter cleanup.
10. Sprint 8.6: Shared formatting and history UI polish.
11. Sprint 8.7: Shared cost rows and consumption card cleanup.
12. Sprint 8.8: Feature view folders.
13. Sprint 9: Lightweight test coverage.

Reasoning:

- Formatters and logging are low-risk and clean up release concerns early.
- Shared status components and history decomposition reduce visible duplication before deeper architecture changes.
- History query abstraction and monthly cost estimation create seams needed for a smaller view model.
- Tests come after the main pure helpers exist, so they protect real behavior instead of locking in current clutter.

## Per-Sprint Definition Of Done

- [ ] Scope stayed within the sprint.
- [ ] No unrelated visual redesign.
- [ ] No new raw provider/user data logs.
- [ ] Xcode diagnostics checked for changed Swift files.
- [ ] Full project build passes.
- [ ] Sprint checklist updated in this document.
