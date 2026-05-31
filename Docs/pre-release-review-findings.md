# Pre-Release Architecture & Implementation Review Findings

**Purpose**  
This document collects observations, weaknesses, and risks identified during a deep walkthrough of the core implementation. The goal is to create a clear, prioritized backlog of things that should be addressed before a serious TestFlight release and especially before App Store submission.

This is **not** a bug list. It is a review of architectural choices, code health, App Store readiness, and long-term maintainability.

**Status**: Living document. Add new findings as they are discovered. Mark items as resolved when fixed.

---

## 1. Overall Architectural Observations

### Positive
- Strong separation between platform shells (macOS menu bar vs iOS app) and shared business logic.
- `SpotPriceViewModel` uses modern `@Observable` + Swift Concurrency.
- History persistence was designed with App Store privacy requirements in mind from the start (`cloudKitDatabase: .none`, no credentials in records, export/delete planned).
- `CostProfile` as a single source of truth for all cost parameters is a powerful concept.

### Areas of Concern
- The app has grown organically. Several layers are starting to show signs of "God Object" behavior or unclear ownership.
- Significant technical debt around deployment targets, privacy manifests, and production hygiene (logging, error handling).
- Very little automated testing exists. This increases risk for any refactoring needed before launch.
- The line between "domain logic", "UI state", and "persistence" is sometimes blurred (especially in ViewModel and Settings).

---

## 2. Critical File / Layer Findings

### 2.1 SpotPriceViewModel.swift

**Role**: Central orchestrator for prices, consumption, tariffs, history recording, and widget cache updates.

**Weaknesses**:

- **Too much responsibility**  
  The ViewModel owns price fetching, consumption loading, tariff loading, power peak calculation, precise monthly cost, history recording (both price-only and consumption-aware), and current-month summary loading. This makes it hard to test and reason about.

- **History recording is a side effect with weak ownership**  
  `historyRecorder?.recordPriceHistory(...)` and `recordCurrentMonthConsumptionHistory(...)` are called from `load()` and `loadConsumption()`. Failures are silently swallowed (only `print`). There is no clear "history service" boundary that the rest of the app can depend on.

- **Inconsistent error handling**  
  Some errors use `DisplayableError`, others become plain strings. The `failed(String)` case loses type information.

- **Duplicate summary loading**  
  `loadCurrentMonthHistorySummary()` is called from multiple places (`load`, `loadConsumption`). Easy to miss or call unnecessarily.

- **Periodic refresh + settings observation are fire-and-forget Tasks**  
  No mechanism to surface that background refreshes are failing long-term.

- **Dependency on `try? EnergyHistoryRecorder()`**  
  If the recorder cannot be created (e.g. missing App Group), history is silently disabled with no user-visible signal.

**Impact**: High for maintainability and reliability. Medium risk for App Store (silent failures are hard to debug in review).

**Suggested direction**: Consider extracting a `PriceRefreshCoordinator` or making history recording an explicit, injectable pipeline with its own error reporting.

---

### 2.2 CostProfile.swift + TotalCostService.swift

**Role**: The heart of the product's value proposition (real total cost in SEK).

**Weaknesses**:

- **CostProfile is extremely large and "god-like"**  
  It contains retail contract, grid costs, taxes, effect tariff, confidence, and source metadata. It has many `updating(...)`, `removingGridCosts(...)`, `settingEffectTariff(...)` convenience methods. This makes it hard to evolve without breaking something.

- **Two different calculation paths in TotalCostService**  
  There are overloaded `calculateTotalCost` and `calculatePricePerKWh` methods with very different signatures (one takes `CostProfile`, another takes `SimplifiedTariff` + separate surcharge/fee values). This is confusing and error-prone.

- **Provider-enhanced calculation path (`calculateTotalCostWithProvider`)** is complex and lives in the service  
  It mixes concerns about "is the provider data fresh?" with cost math.

- **Effect tariff calculation is buried**  
  `calculateEffectTariffCost` exists, but the actual different models (single peak, average top 3/5, etc.) are not clearly modeled as strategies.

- **No clear "CostCalculationContext" or snapshot concept** at the call site  
  Callers must know exactly which overload to use.

**Impact**: High for correctness and future features (e.g. historical recalculation). Medium-high risk when adding new tariff types or changing how provider data overrides user settings.

**Suggested direction**: Introduce a clearer calculation pipeline or a `CostCalculationRequest` value type.

---

### 2.3 History Layer (HistoricalEnergyModels + EnergyHistoryStore + EnergyHistoryRecorder)

**Role**: Local-first, privacy-respecting history for prices, consumption, and calculated costs.

**Weaknesses** (many of these are known and documented in the original plan, but still present in code):

- **Very large `SwiftDataEnergyHistoryStore`** (680+ lines)  
  It does upsert, summary rebuilding, widget cache maintenance, CSV export, pruning, and multiple private helper methods. It mixes persistence, aggregation, and cross-target concerns (widget cache).

- **Summary rebuilding happens synchronously inside `upsertRecords`**  
  After every price or consumption batch, the store rebuilds daily + monthly summaries for affected periods. This can become expensive as history grows.

- **Widget summary cache is updated from inside the store**  
  The store has direct knowledge of `WidgetHistorySummaryCache`. This creates a hidden coupling between the history layer and the widget.

- **Recorder does heavy lifting**  
  `EnergyHistoryRecorder` performs spot price lookup, interval matching, and calls `TotalCostService`. It is marked `@MainActor` but does significant async work. Ownership of "when to record" lives in the ViewModel.

- **No migration strategy tested yet**  
  Schema version is `1.0.0`, but there are no migration tests or explicit migration logic beyond what SwiftData provides.

- **Error surface is inconsistent**  
  Some methods throw, some just print. The public `EnergyHistoryStore` protocol throws, but many call sites ignore errors.

**Impact**: High for long-term storage growth and widget performance. Medium risk for App Store if history ever behaves unexpectedly or grows unbounded.

**Suggested direction** (from original plan): Consider a dedicated summary service or background queue for aggregation. Make widget cache updates more explicit.

---

### 2.4 ConsumptionSettings.swift

**Role**: The single source of truth for all user configuration, shared via App Group + UserDefaults + Keychain.

**Weaknesses**:

- **Massive God Object**  
  It holds price area, retail contract values, grid settings, fuse size, selected provider, credentials (in-memory + Keychain), cached consumption, cached tariff, and the full `CostProfile`. It also contains a lot of legacy property bridges (`customerId`, `password`, etc.).

- **CostProfile is both stored and derived**  
  `costProfile` is persisted, but many individual properties (`providerSurchargePerKWh`, `fuseSize`, etc.) also exist and can drift. There is mirroring logic (`mirrorCostProfileToLegacyDefaults`, `syncLegacyProperties`).

- **Credentials storage has a migration path that still runs**  
  On every `loadAllCredentials()` it checks UserDefaults for legacy data. This migration code will live forever unless explicitly removed later.

- **Heavy use of `didSet` with side effects**  
  Saving, posting notifications, calling `WidgetCenter.shared.reloadAllTimelines()`, and synchronizing happens in `didSet`. This makes the class hard to reason about and test.

- **No clear "dirty" or "needs save" concept**  
  Every tiny change immediately persists and notifies the world.

**Impact**: Very high for maintainability and risk of subtle bugs when settings change. This is one of the most dangerous classes to touch.

**Suggested direction**: Consider splitting into smaller focused types (e.g. `RetailContractSettings`, `GridTariffSettings`, `ProviderConnection`) behind a facade, or at least make persistence explicit.

---

## 3. Cross-Cutting Concerns

### 3.1 Deployment Targets (Critical Blocker)
- `MACOSX_DEPLOYMENT_TARGET = 26.0`
- `IPHONEOS_DEPLOYMENT_TARGET = 26.2`

These targets are unrealistic for the foreseeable future. This will prevent building on real devices or submitting to TestFlight/App Store.

**Priority**: Must fix before any external build.

### 3.2 Privacy & App Store Submission Hygiene
- No `PrivacyInfo.xcprivacy` manifest exists.
- Info.plist files are minimal (especially on iOS side).
- No clear privacy policy text or App Store Connect privacy answers prepared for local history storage, Keychain usage, or network calls to `elprisetjustnu.se` + provider APIs.

### 3.3 Production Logging
- ~47 `print()` statements across the codebase (ViewModel, services, widget, settings views).
- Many are left over from development (`📊 ViewModel: ...`, `🕘 History: ...`).
- No structured logging or log levels. In a released app this pollutes device logs and can leak information.

### 3.4 Error Handling & User Communication
- Many operations are "best effort" with only console logging on failure (tariff fetch, precise cost, power peaks, history recording).
- Users have very little visibility when something is estimated vs measured vs unavailable.

### 3.5 Testing
- No test target exists (documented as future epic).
- Core logic (`TotalCostService`, history aggregation, `CostProfile` calculations) has no automated coverage.
- This makes safe refactoring before launch difficult.

### 3.6 Widget Data Access
- Widget relies on App Group UserDefaults + a hand-maintained `WidgetHistorySummaryCache`.
- It cannot easily read SwiftData directly (performance + entitlement reasons).
- The cache can become stale without clear invalidation signals.

### 3.7 macOS vs iOS Parity & Polish
- Several macOS-specific APIs and views still live under the `Spotprice` target (even if some have been moved).
- iOS app still has some legacy template code references in older planning docs.
- Settings experience is quite different between platforms (macOS `Settings` scene vs iOS sheet).

---

## 4. Recommended Prioritization for Launch

**Must fix before TestFlight / App Store**:
- Deployment targets
- Privacy manifest + basic privacy copy
- Removal or gating of noisy debug prints in release builds
- Clear handling of "history unavailable" states

**Strongly recommended before public release**:
- Reduce god-object nature of `ConsumptionSettings` and `SpotPriceViewModel`
- Improve error visibility for best-effort operations
- Add at least basic unit tests around cost calculation and history key generation

**Can be deferred (but document the debt)**:
- Full test target and high coverage
- CloudKit sync for history
- Major refactoring of the calculation layer
- Advanced history recalculation UI

---

## 5. How to Use This Document

- When starting a new sprint or review session, pick 1–2 items from this list.
- Create a focused task with clear acceptance criteria.
- Update this document when an item is resolved or when new findings appear.
- Keep the tone constructive — the goal is to ship a solid, trustworthy product.

---

**Last updated**: During architecture walkthrough session (May/June 2026)

**Next step recommendation**: Decide on a small set of high-impact items to tackle in the next 1–2 weeks before any external TestFlight build.