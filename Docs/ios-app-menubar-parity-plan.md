# iOS App Menubar Parity Plan

Goal: bring the core functionality currently shown in the macOS menu bar view into the new iOS app, while keeping data, models, services, and reusable presentation pieces shared.

## Current State

- macOS menu bar target uses `ModernMenuBarView` as the main dashboard.
- iOS app target currently launches `SpotPriceChartView`, a simple chart-focused view.
- Shared state already exists in `SpotPriceViewModel`.
- Shared business logic already exists in services and models under `Shared`.
- Several useful UI pieces currently live under the macOS target even though most of them are not inherently macOS-specific.
- Some macOS-only UI APIs are mixed into reusable views, especially `SettingsLink`, `.help`, and `NSApplication.shared.terminate(nil)`.

## Target Outcome

The iOS app should show a native full-screen dashboard with the same core content as the menu bar:

- Current total electricity cost.
- Day price chart.
- Today min, max, and average stats.
- Cost examples for common activities.
- Monthly consumption and estimated or precise monthly cost.
- A lightweight monthly cost forecast in the cost hero, based on cost-to-date scaled by elapsed month progress.
- Configuration/status messaging when consumption is not configured.

The iOS version does not need to copy the menu bar window chrome. It should use iOS navigation, scrolling, toolbar/settings entry, and responsive layout.

## Architecture Direction

Keep this boundary:

- `Shared`: models, services, view models, design system, data helpers, and platform-neutral reusable SwiftUI components.
- `Spotprice`: macOS menu bar shell and macOS-specific views/actions.
- `SpotpriceApp`: iOS app shell and iOS-specific views/actions.
- `SpotpriceWidget`: widget-specific presentation.

Do not move a component to `Shared` until it compiles and makes sense on both macOS and iOS.

## Step 1: Inventory Menubar Dashboard Pieces

Audit `ModernMenuBarView` and classify every dependency:

Reusable or mostly reusable:

- `SpotPriceBarChart`
- `StatCardView`
- `CostCalculationSection`
- `CostCardView`
- `CostBreakdownRow`
- `CostBreakdownSubRow`
- `MonthlyStatsSection`
- `MonthlyCostCard`
- `TopConsumptionDaysCard`
- `ConsumptionStatCard`
- `ConnectionStatus`
- `ChartCalloutView`

macOS-specific or needs adaptation:

- `ModernMenuBarView` itself, because it has fixed menu bar sizing and macOS window controls.
- Header actions using `SettingsLink` and `NSApplication.shared.terminate(nil)`.
- Settings-related views may need iOS navigation instead of macOS settings windows.

Exit criteria:

- We know which files can be shared directly and which need platform wrappers.

## Step 2: Create the iOS Dashboard Shell

Add a new iOS-specific view, suggested name:

- `SpotpriceApp/DashboardView.swift`

Responsibilities:

- Own `@State private var viewModel = SpotPriceViewModel()`.
- Trigger `await viewModel.load()` once when state is idle.
- Render a `NavigationStack` or root `ScrollView`.
- Show a toolbar/settings button instead of the menu bar gear/quit buttons.
- Use flexible iOS layout instead of fixed `DS.Size.menuBarWidth` and `DS.Size.menuBarHeight`.

Initial content order:

1. App/header row.
2. Current cost hero.
3. Chart section.
4. Quick stats.
5. Cost calculation examples.
6. Monthly stats.

Exit criteria:

- iOS app launches into a dashboard view rather than the placeholder/simple chart only.
- No macOS-only API is referenced from the iOS target.

## Step 3: Share the Chart and Supporting Views

Move or add target membership for platform-neutral chart dependencies.

Candidate shared files:

- `Spotprice/Views/SpotPriceBarChart.swift`
- `Spotprice/Views/ChartCalloutView.swift`
- `Spotprice/Views/StatCardView.swift`

Potential blockers:

- `SpotPriceBarChart` uses newer Charts APIs such as `chartXSelection`; verify iOS deployment target supports them.
- The chart uses `DS` design tokens and `TotalCostService`, which are already shared.

Exit criteria:

- iOS dashboard can render the same day chart from `SpotPriceViewModel.CurrentAndDay.day`.
- macOS menu bar chart still builds.

## Step 4: Share Quick Stats and Cost Examples

Extract the quick-stat calculation currently embedded in `ModernMenuBarView` into one of these:

- a shared `PriceStatsSection` SwiftUI component, or
- small shared helper methods plus separate macOS/iOS layout views.

Move or add target membership for:

- `CostCalculationSection`
- `CostCardView`
- `CostBreakdownRow`
- `CostBreakdownSubRow`
- `StatCardView`

Keep iOS layout responsive:

- Use a two-column grid on wider phones/tablets.
- Allow one-column layout if text becomes cramped.
- Avoid fixed menu bar dimensions.

Exit criteria:

- iOS shows min, max, average, and common activity cost examples.
- Values match the macOS menu bar for the same `SpotPriceViewModel` state and `CostProfile`.

## Step 5: Bring Monthly Consumption Into iOS

Cost hero forecast behavior:

- Show a `Prognos` inline metric only when current-month consumption data is available.
- Estimate cost-to-date from current-month kWh, the cost profile, and elapsed hours in the month.
- Prefer the matched 15-minute spot average from `PreciseMonthlyCost` when available; otherwise use the current day price fallback already available to the cost tab.
- Scale cost-to-date linearly by elapsed month progress. This is intentionally a simple first pass, not a seasonal or behavior-based forecast model.

Move or add target membership for monthly-stat components:

- `MonthlyStatsSection`
- `MonthlyCostCard`
- `TopConsumptionDaysCard`
- `ConsumptionStatCard`

Adapt platform-specific behavior:

- Replace `SettingsLink` inside reusable views with an injected action or a neutral configuration call-to-action component.
- On macOS, the action can open Settings.
- On iOS, the action can navigate or present a settings screen when that exists.

Exit criteria:

- iOS dashboard shows monthly consumption, monthly cost, and power peaks when data is available.
- iOS shows a sensible setup prompt when consumption is not configured.

## Step 6: Add iOS Settings Path

The iOS dashboard needs a way to configure the same data that powers the menu bar:

- Price area.
- Consumption provider.
- Provider credentials.
- Retail contract/cost profile.
- Grid tariff/DSO settings.

Recommended first pass:

- Create `SpotpriceApp/Settings/DashboardSettingsView.swift` or similar.
- Reuse `ConsumptionSettings.shared` and shared provider metadata.
- Port only the minimum settings needed to make the dashboard useful.

Do not blindly move macOS `SettingsView` as-is if it relies on macOS-only layout or settings scene behavior.

Exit criteria:

- iOS can update `ConsumptionSettings` values used by the dashboard.
- `SpotPriceViewModel` reloads when settings change.

## Step 7: Remove Placeholder SwiftData Template Pieces If Unused

The current iOS app still has template files:

- `ContentView.swift`
- `Item.swift`
- SwiftData model container setup in `SpotpriceAppApp.swift`

Once the dashboard is the real root UI, decide whether SwiftData is needed.

If not needed:

- Remove `Item` and the model container.
- Remove `ContentView` or keep it only if it has a real purpose.

Exit criteria:

- iOS app root is clean and purpose-built for Spotprice.
- No unused template storage code remains.

## Step 8: Validation After Each Slice

After each implementation slice:

1. Refresh diagnostics on touched Swift files.
2. Build the project.
3. Check both targets still compile:
   - macOS app/menu bar target.
   - iOS app target.
4. Verify the shared component did not accidentally import AppKit or use macOS-only APIs.

For visual validation:

- Render SwiftUI previews where available.
- Run the iOS app and check narrow phone and iPad-width layouts.
- Confirm text does not clip in cards, toolbar, chart labels, or monthly stats.

## Suggested Implementation Order

1. Create `DashboardView` for iOS with current price, loading/error states, and the simple existing chart.
2. Replace the simple chart with the richer shared `SpotPriceBarChart`.
3. Add quick stat cards.
4. Add cost example cards.
5. Add monthly stats.
6. Add iOS settings entry and minimum settings screen.
7. Remove unused SwiftData template code.
8. Revisit iOS widget plan after dashboard/settings data flow is stable.

## Non-Goals For First Pass

- Do not create the iOS widget yet.
- Do not redesign the macOS menu bar UI.
- Do not introduce a new persistence layer unless we need it.
- Do not move every macOS view into `Shared` at once.
- Do not make iOS mimic the fixed-size menu bar window.
