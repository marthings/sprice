# Test Epic Plan

Goal: add automated coverage deliberately, after the current product and persistence flows have stabilized. This is a future epic, not part of the current history sprint.

## Why This Is Separate

The project does not currently have a test target or established test patterns. Adding meaningful tests therefore includes project setup, fixtures, dependency seams, and conventions. Treating this as a small checklist item would create shallow tests and fragile scaffolding.

## Scope

### 1. Test Infrastructure

- [ ] Add a unit test target for shared business logic.
- [ ] Use Swift Testing for new unit tests where practical.
- [ ] Use XCTest only where required by Xcode, UI automation, or framework constraints.
- [ ] Add a convention for test fixtures and builders.
- [ ] Make tests runnable from Xcode schemes.

### 2. History Persistence Tests

- [ ] Use `EnergyHistoryModelContainer.makeInMemoryContainer()` for store tests.
- [ ] Test application-level deduplication by `deduplicationKey`.
- [ ] Test price-only record insertion.
- [ ] Test measured consumption record insertion.
- [ ] Test partial consumption history when some intervals lack matching prices.
- [ ] Test provider-separated records for the same month.
- [ ] Test daily summary aggregation.
- [ ] Test monthly summary aggregation.
- [ ] Test top cost days and top consumption days queries.
- [ ] Test widget summary cache generation.
- [ ] Test delete and retention pruning.
- [ ] Test CSV export format and escaping.

### 3. Cost Model Tests

- [ ] Test Swedish default estimate.
- [ ] Test omitted default grid cost.
- [ ] Test quarter-price retail contracts.
- [ ] Test variable monthly retail contracts.
- [ ] Test fixed-price retail contracts.
- [ ] Test retailer monthly fee handling.
- [ ] Test grid monthly and transfer fee handling.
- [ ] Test energy tax and certificate fee handling.
- [ ] Test disabled and enabled effect tariff behavior.
- [ ] Test confidence label rules.

### 4. Settings And Migration Tests

- [ ] Test legacy settings migration into `CostProfile`.
- [ ] Test manual grid values overriding imported tariff values.
- [ ] Test provider switching clears cached live consumption but keeps local history.
- [ ] Add schema migration tests when a SwiftData schema v2 exists.

### 5. UI Smoke Tests

- [ ] Add minimal launch tests for macOS app if practical.
- [ ] Add minimal launch tests for iOS app.
- [ ] Test that iOS dashboard can load the main tabs.
- [ ] Test settings screens open without crashing.

## Definition Of Done

- Tests cover the shared logic most likely to regress: cost calculation, history aggregation, deduplication, export/delete, and settings migration.
- Tests run from Xcode without manual setup.
- New persistence or cost-model changes are expected to add or update tests.

