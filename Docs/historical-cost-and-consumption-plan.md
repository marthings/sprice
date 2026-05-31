# Historical Cost And Consumption Plan

Goal: add local history for prices, consumption, and calculated electricity costs so the app can show trends, monthly reports, widgets, and past periods even when provider APIs only return limited data.

The first implementation should be local-first. A backend or cloud sync can be added later, but should not be required for the core value.

This feature must be App Store-ready: no hidden data collection, no provider credentials in history records, clear local storage behavior, and user-facing controls for export and deletion before the feature is treated as complete.

## Product Outcome

The user should be able to answer these questions:

- What did electricity cost me today, this week, and this month?
- How much did I consume when a provider is connected?
- Which days or hours drove the cost?
- How has my cost changed over time?
- What data is measured, estimated, or unavailable?

The app should work in three levels:

- Price only: store spot price history and show price trends.
- Estimated cost: store calculated cost using the current or selected `CostProfile`, even without provider consumption.
- Measured consumption: store consumption-aware cost snapshots when provider data is available.

## Architecture Direction

Keep history as a shared service layer, not as view state.

Suggested files:

```text
Shared/Models/HistoricalEnergyModels.swift
Shared/Services/EnergyHistoryStore.swift
Shared/Services/EnergyHistoryRecorder.swift
Shared/Services/EnergyHistoryQueryService.swift
```

Responsibilities:

- `EnergyHistoryStore`: persistence only. Save, update, fetch, delete, and migrate records.
- `EnergyHistoryRecorder`: converts live price, provider consumption, and cost calculations into immutable history snapshots.
- `EnergyHistoryQueryService`: builds day, month, and trend summaries for app, menu bar, and widget.
- `TotalCostService`: remains the source of truth for cost math. It should not become a database service.
- `SpotPriceViewModel`: orchestrates recording after successful refreshes, but should not own persistence details.

## Data Model

Start with hourly records because they support both detailed charts and monthly aggregation. If a provider returns quarter-hour values, aggregate to hourly initially unless quarter-hour history becomes a clear product requirement.

Use SwiftData model classes for persistence and separate value structs for UI/query results. Keep the persisted models flat and mostly scalar so they stay CloudKit-compatible later.

Suggested persisted model shape:

```swift
@Model
final class HistoricalEnergyRecord {
    var id: UUID
    var deduplicationKey: String
    var intervalStart: Date
    var intervalEnd: Date
    var dayKey: String
    var monthKey: String
    var priceArea: String
    var providerID: String?

    var spotPriceOrePerKWh: Double
    var consumptionKWh: Double?

    var energyCostSEK: Double?
    var gridCostSEK: Double?
    var taxCostSEK: Double?
    var vatCostSEK: Double?
    var totalCostSEK: Double?

    var costProfileSnapshotData: Data?
    var sourceRawValue: String
    var confidenceRawValue: String
    var createdAt: Date
    var updatedAt: Date
}
```

Important principles:

- Store calculated cost components as snapshots so old history does not change unexpectedly when the user updates settings.
- Store enough `CostProfile` metadata to explain historical calculations and optionally recalculate later, but encode that snapshot as value data instead of a required relationship.
- Use application-level upsert by `deduplicationKey`; do not rely on SwiftData unique constraints if CloudKit sync is enabled later.
- Keep `consumptionKWh` optional so price-only history is still useful.
- Mark records as estimated, measured, imported, or recalculated.
- Store `dayKey` and `monthKey` as denormalized query keys so common fetches do not require date math over a large dataset.
- Keep provider credentials out of history records.

## Persistence Choice

Recommended start: SwiftData stored locally on the device in the shared App Group container. Design the schema so CloudKit can be added later, but do not enable CloudKit sync in the first implementation.

Rationale:

- SwiftData gives us a queryable local store now instead of a large JSON file that becomes hard to aggregate and prune.
- SwiftData can use CloudKit-managed sync later through `ModelConfiguration`, but the first version should remain local-only.
- The widget can read cheap precomputed summaries from the App Group without provider credentials.
- A SwiftData model layer gives us a migration path as history evolves.

CloudKit constraints to respect from day one:

- Do not depend on `@Attribute(.unique)` for deduplication because CloudKit sync cannot enforce uniqueness reliably.
- Avoid required relationships in synced models; use flat scalar fields or optional relationships only.
- Treat the production CloudKit schema as additive-only once shipped. Avoid early model churn in synced record types.
- Use `cloudKitDatabase: .none` for the initial implementation. Enable private database sync only in a later explicit sync sprint.

Current local schema readiness:

- SwiftData history uses explicit schema version `1.0.0` through `EnergyHistoryModelContainer.CurrentSchema`.
- The production configuration remains `cloudKitDatabase: .none`.
- All persisted history models are flat classes with scalar or optional properties.
- Deduplication is application-level through `deduplicationKey`, not `@Attribute(.unique)`.
- Cost profile details are stored as optional encoded value data, not as a required relationship.
- Widget history uses a compact App Group `UserDefaults` cache derived from summaries, not direct provider credentials.

CloudKit sync remains blocked until a later explicit sync sprint defines:

- User-facing opt-in/out setting and privacy copy.
- iCloud entitlement setup for all relevant targets.
- Migration plan from local-only store to private CloudKit database.
- Conflict behavior for duplicate interval records across devices.
- Backfill/rebuild strategy for daily and monthly summaries after sync merges.
- App Store privacy review updates for synced historical data.

Large-data strategy:

- Store raw interval records for detailed history.
- Store daily and monthly summary models so dashboards and widgets do not scan all raw records.
- Query by `monthKey`, `dayKey`, `priceArea`, and date range.
- Upsert changed intervals in batches after refreshes.
- Add retention/export/delete controls before storage grows silently.
- Keep widget reads against summary records or a compact summary cache, not raw interval history.

## App Store And Privacy Requirements

Treat historical electricity data as user data even when it is stored only on device. The implementation should be conservative and easy to explain during App Review.

Requirements:

- Store history locally on device in the App Group container for the first release.
- Keep `cloudKitDatabase: .none` until CloudKit sync is implemented as an explicit user-facing feature.
- Do not send historical consumption or cost records to our own servers or third-party analytics.
- Do not include provider credentials, access tokens, names, addresses, or account identifiers in history records.
- Use stable provider IDs such as `tibber` or `vaggeryd`, not provider account IDs.
- Add user controls to export and delete local history before the history feature is considered release-complete.
- Add clear privacy copy explaining that history is stored locally on the device and shared only between the app, menu bar app, and widget through the App Group container.
- Keep App Store Connect privacy answers aligned with actual behavior. Local-only processing is not the same as collecting data off-device, but any future CloudKit sync or server upload changes the privacy review.
- Maintain `PrivacyInfo.xcprivacy` entries for required reason APIs used by the app, including preferences or file/storage APIs if applicable.
- Avoid third-party SDKs for analytics or storage in this feature unless their privacy manifests and data practices are reviewed.

Release gates:

- [ ] Verify no history data leaves the device in the initial implementation.
- [ ] Verify history records contain no credentials or direct personal identifiers.
- [ ] Add export and delete controls.
- [ ] Add privacy policy/App Store privacy copy for local history behavior.
- [ ] Review `PrivacyInfo.xcprivacy` before submission.
- [ ] Re-run this checklist before enabling CloudKit or any backend sync.

## Sprint Plan

### Sprint 1: History Foundation

Purpose: define the domain model and persistence boundary without changing UI behavior.

Tasks:

- [x] Add SwiftData `HistoricalEnergyRecord`, source, confidence, and summary models.
- [x] Add `HistoricalCostProfileSnapshot` with the cost settings needed to explain old calculations.
- [x] Add `EnergyHistoryStore` protocol backed by SwiftData.
- [x] Configure `ModelContainer` for the App Group container.
- [x] Configure SwiftData with `cloudKitDatabase: .none`; history is local to the device in this phase.
- [x] Add application-level upsert behavior for hourly records using `deduplicationKey`.
- [x] Add simple fetch APIs for date range, `dayKey`, and `monthKey`.
- [x] Add unit-testable pure helpers for record keys and aggregation.

Exit criteria:

- Shared code can save and read hourly history records.
- Store has no dependency on SwiftUI or view models.
- Existing app behavior is unchanged.

### Sprint 2: Record Price History

Purpose: start collecting useful history for every user, even without provider setup.

Tasks:

- [x] Add `EnergyHistoryRecorder`.
- [x] Record spot price history after successful `SpotPriceService` refresh.
- [x] Store current `priceArea` with each record.
- [x] Avoid duplicate records on repeated refreshes.
- [x] Add lightweight logging for record count and update failures.
- [x] Keep recording failures non-fatal for the main price refresh.

Exit criteria:

- The app accumulates local price history day by day.
- Refresh still succeeds if history saving fails.
- Price-only users get future value from history.

### Sprint 3: Record Consumption And Cost Snapshots

Purpose: persist measured or estimated costs when consumption data is available.

Tasks:

- [x] Connect recorder to `ConsumptionService` output.
- [x] Match consumption intervals with spot price intervals.
- [x] Use `TotalCostService` to calculate cost components.
- [x] Store `consumptionKWh`, cost components, total cost, provider ID, and confidence.
- [x] Decide how to mark incomplete provider data for current day/month.
- [x] Add recalculation guardrails so settings changes do not silently rewrite old costs.

Exit criteria:

- Provider-connected users accumulate measured consumption and cost history.
- Records clearly distinguish measured consumption from estimates.
- Old snapshots remain stable when settings change.

### Sprint 4: Query And Summary Layer

Purpose: expose history in app-friendly shapes without duplicating aggregation logic in views or scanning large raw datasets.

Tasks:

- [x] Add SwiftData daily summary model.
- [x] Add SwiftData monthly summary model.
- [x] Update summaries incrementally when interval records are inserted or changed.
- [x] Add top cost days and top consumption days queries.
- [x] Add average, min, max, and total helpers.
- [x] Add missing-data indicators for partial months and incomplete provider periods.
- [x] Add query APIs intended for widget use.
- [ ] Add a compact widget summary cache if direct SwiftData reads are too heavy for widget timelines.

Exit criteria:

- Views can ask for history summaries directly.
- Summary logic is shared across macOS, iOS, and widget.
- Common UI reads use daily/monthly summaries instead of full raw-history scans.
- Missing or partial data is explicit in the model.

### Sprint 5: UI Integration

Purpose: make history visible without overloading the existing dashboard.

Tasks:

- [x] Add a history/month view in iOS app.
- [x] Add a compact historical summary to macOS menu bar if space allows.
- [x] Update monthly cards to prefer persisted history when available.
- [x] Show measured vs estimated labels.
- [x] Add empty states for no history yet and no provider connected.
- [x] Add settings entry for history storage status.

Exit criteria:

- Users can inspect at least current month and previous stored periods.
- UI clearly communicates whether cost is measured, estimated, or price-only.
- Existing live dashboard remains fast and readable.

### Sprint 6: Widget And Background Refresh

Purpose: let history improve passive glance surfaces.

Tasks:

- [x] Let widget read precomputed summaries from App Group storage.
- [x] Avoid provider API calls from widget.
- [ ] Add background refresh recording path if supported by target/platform.
- [x] Persist a small widget summary cache to keep widget reads cheap.
- [x] Handle stale data display explicitly.

Exit criteria:

- Widget can show monthly cost/consumption from saved history.
- Widget does not need provider credentials.
- Stale or partial history is visible to the user.

### Sprint 7: Maintenance, Migration, And Controls

Purpose: make local device history sustainable before adding multi-device sync.

Tasks:

- [x] Add SwiftData schema versioning or migration support.
- [x] Keep CloudKit disabled and document the remaining requirements for a later sync sprint.
- [x] Validate that the local SwiftData schema is still compatible with future CloudKit constraints.
- [x] Add history export option, likely CSV.
- [x] Add delete history option.
- [x] Add retention policy if storage grows too much.
- [ ] Add manual recalculation flow for selected periods using current settings.
- [x] Move automated tests into a separate future test epic.

Exit criteria:

- Users can inspect, export, and delete their local history.
- Future model changes have a migration path.
- Storage growth is bounded or visible.

## Open Decisions

- Store granularity: hourly first, or preserve quarter-hour records from day one?
- Future CloudKit sync: what user setting, entitlement setup, migration, and conflict behavior do we need before enabling multi-device history?
- Recalculation UX: should users be able to recalculate old periods after changing tariffs?
- Data retention: keep everything forever locally, or provide a default retention window?
- Provider import: should we backfill historical provider data when an integration is first connected?
- Privacy copy: where do we explain that history is local and does not include provider credentials?

## Suggested Implementation Order

Build in this order:

1. SwiftData models and store protocol.
2. App Group `ModelContainer` with local-only CloudKit mode.
3. Price-only recording.
4. Consumption-aware recording.
5. Incremental daily/monthly summaries.
6. UI display.
7. Widget and background paths.
8. Export, delete, migration, local storage controls, and recalculation controls.
9. Future test epic: unit coverage for cost math, persistence, aggregation, export/delete, and migration.
10. Later separate sprint: CloudKit sync, conflict handling, and multi-device UX.

This keeps the data foundation stable before UI depends on it, while still delivering value early through price history.
