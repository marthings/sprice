# Tariffs And Costs Sprint

## Goal

Make Sprice useful without a connected provider by showing an estimated total electricity cost by default, then let the user improve precision step by step through settings.

The app should treat provider integrations as optional data enrichment, not as a requirement for cost calculation.

## Product Principle

The user should always see a cost:

- No setup: estimated total cost
- Basic setup: customized total cost
- Tariff match: tariff-based total cost
- Provider connection: consumption-aware cost

## Sprint Checklist

### 1. Define Central Cost Profile

- [x] Add `CostProfile`
- [x] Add `CostConfidence`
- [x] Add optional `EffectTariff`
- [x] Add `TariffSource` or equivalent source metadata
- [x] Make the model `Codable` and `Sendable`
- [x] Decide which values are stored as ore/kWh, kr/month, and percentages

Target result:

```swift
struct CostProfile: Codable, Sendable {
    let priceArea: String
    let retailerMarkupOrePerKWh: Double
    let retailerMonthlyFee: Double
    let gridCompanyId: String?
    let gridCompanyName: String?
    let fuseSize: Int?
    let gridMonthlyFee: Double?
    let gridTransferOrePerKWh: Double?
    let energyTaxOrePerKWh: Double
    let certificateFeeOrePerKWh: Double
    let vatRate: Double
    let effectTariff: EffectTariff?
    let confidence: CostConfidence
}
```

### 2. Add Swedish Default Estimate

- [x] Add a default profile factory
- [x] Default price area to `SE3`
- [x] Include standard retailer markup estimate
- [x] Include standard electricity tax
- [x] Include certificate/minor fee estimate
- [x] Set grid fees to unknown by default
- [x] Disable effect tariff by default
- [x] Mark default profile as `.estimated`

Product label:

```text
Uppskattat totalpris
```

### 3. Refactor Total Cost Calculation

- [x] Add profile-based methods to `TotalCostService`
- [x] Keep old methods temporarily for migration
- [x] Calculate total kr/kWh from spot price and `CostProfile`
- [x] Calculate appliance/example costs from `CostProfile`
- [x] Include monthly fee proration in one place
- [x] Add clear handling for unknown grid fees
- [x] Add clear handling for disabled effect tariff

Target API:

```swift
func calculatePricePerKWh(
    spotPriceOre: Double,
    profile: CostProfile
) -> Double

func calculateTotalCost(
    kWh: Double,
    spotPriceOre: Double,
    profile: CostProfile,
    hoursInPeriod: Double
) -> EnhancedCost
```

### 4. Store And Migrate Settings

- [x] Add persisted `CostProfile` support to `ConsumptionSettings`
- [x] Build initial profile from existing settings
- [x] Migrate `priceArea`
- [x] Migrate `providerSurchargePerKWh`
- [x] Migrate `providerMonthlyFee`
- [x] Migrate `selectedDSOOrgNo`
- [x] Migrate `fuseSize`
- [x] Migrate `cachedTariff` when available
- [x] Keep old keys readable during transition
- [x] Post settings change notification when profile changes

### 5. Update Settings Flow

- [x] Reorganize settings into layered precision sections
- [x] Add section: `Elområde`
- [x] Add section: `Uppskattning`
- [x] Add section: `Elnät`
- [x] Add section: `Elhandelsavtal`
- [x] Add section: `Förbrukningsdata`
- [x] Add section: `Avancerat`
- [x] Make provider connection optional and later in the flow
- [x] Show current confidence level in settings

Suggested settings order:

```text
1. Elområde
2. Uppskattning
3. Elnät
4. Elhandelsavtal
5. Förbrukningsdata
6. Avancerat
```

### 6. Add Manual Retailer Inputs

- [x] Add retailer markup field in öre/kWh
- [x] Add retailer monthly fee field in kr/month
- [x] Add reset-to-default action
- [x] Use provider defaults only as suggestions
- [x] Avoid requiring retailer/provider selection

### 7. Add Manual Grid Inputs

- [x] Add optional grid company picker
- [x] Add manual grid monthly fee field
- [x] Add manual transfer fee field in öre/kWh
- [x] Add fuse size selector
- [x] Prefill from tariff data when available
- [x] Allow manual override when tariff data is missing
- [x] Mark profile as `.userConfigured` when user enters values

### 8. Make Effect Tariff Optional

- [x] Remove effect tariff from default assumptions
- [x] Add explicit enable/disable control
- [x] Add fields for effect tariff values only when enabled
- [x] Support tariff-database-provided effect tariff
- [x] Support manual effect tariff entry
- [x] Show explanatory text that effect tariffs vary by grid company
- [x] Keep effect tariff out of primary onboarding

Product text:

```text
Effektavgift används bara om ditt elnätsbolag har det.
```

### 9. Update Menu Bar UI

- [x] Use `CostProfile` for quick stats
- [x] Use `CostProfile` in appliance cost examples
- [x] Show estimated/customized/verified label near total cost
- [x] Show total cost even without tariff/provider
- [x] Add a small precision prompt when profile is estimated
- [x] Avoid blocking the main view on provider configuration

Suggested prompt:

```text
Förbättra precisionen
Lägg till elnätsavgift eller elavtal.
```

### 10. Update Widget

- [x] Persist enough profile data for widget access
- [x] Use `CostProfile` in widget price calculation
- [x] Show estimated total cost without provider
- [x] Show configured total cost when user has settings
- [x] Keep cached consumption optional
- [x] Avoid widget-only duplicate cost logic

### 11. Tariff Data Strategy

- [x] Keep Swedish default estimate as fallback
- [x] Keep user-entered values as first-class data
- [x] Convert existing mock DSO data into tariff presets or remove it
- [x] Add local presets for largest DSOs only if useful
- [x] Prepare for remote tariff database/API
- [x] Track tariff data source and freshness
- [x] Add tariff expiry or validity handling

Resolution order:

```text
1. Swedish default estimate
2. User-entered values
3. Local bundled tariff presets
4. Remote tariff database/API
5. Provider-verified data
```

### 12. Provider Role Cleanup

- [x] Treat Tibber/Vaggeryd as consumption data providers
- [x] Avoid requiring provider selection for total cost
- [x] Rename UI copy from provider setup to consumption connection where appropriate
- [x] Keep provider defaults as optional suggestions
- [x] Ensure missing credentials only affects consumption views

### 13. Build And Manual Validation

- [x] Validate app builds
- [x] Validate widget builds
- [x] Manually verify first launch shows estimated total cost
- [x] Manually verify default total cost omits grid cost
- [x] Manually verify user-entered retailer settings switch label to `Anpassat`
- [x] Manually verify provider connection removes the confidence label
- [x] Manually verify missing provider credentials only affects consumption views

### 14. Copy And Trust

- [x] Use consistent product terms
- [x] Explain estimated versus configured cost clearly
- [x] Avoid implying exact invoice match for estimated costs
- [x] Add short disclosure for taxes and grid fees
- [x] Add confidence label wherever total cost is shown

Suggested labels:

```text
Uppskattat
Anpassat
No label when provider data is connected
```

Confidence label meaning:

```text
The confidence label is a small trust indicator beside total cost that explains how exact the number is.
It should not dominate the UI, but it should make clear whether the cost is estimated or user-configured.
When provider data is connected, omit the confidence label.
```

Recommended menu-bar labels:

```text
Uppskattat
Anpassat
No label when provider data is connected
```

## New Product Flow

### First Launch

- [ ] App opens without setup
- [ ] Uses default `SE3` estimate
- [ ] Shows current spot price
- [ ] Shows estimated total cost
- [ ] Shows low/high/average total cost
- [ ] Shows appliance examples
- [ ] Offers precision improvement in settings

Flow:

```text
Open app
→ No setup detected
→ Show estimated total cost
→ User can change elområde
→ App is useful immediately
```

### Improve Precision

- [ ] User opens settings
- [ ] User selects price area
- [ ] User adds retailer markup/monthly fee
- [ ] User optionally adds grid fees
- [ ] User optionally selects grid company/fuse size
- [ ] App updates confidence from estimated to customized

Flow:

```text
Settings
→ Elområde
→ Elhandelsavtal
→ Elnät
→ Customized total cost
```

### Connect Consumption Data

- [ ] User connects Tibber, Vaggeryd, or future source
- [ ] App fetches monthly consumption
- [ ] App fetches daily/hourly/quarterly consumption when available
- [ ] Monthly stats appear
- [ ] Precise monthly cost appears when enough data exists

Flow:

```text
Settings
→ Förbrukningsdata
→ Connect provider
→ Consumption-aware insights
```

### Effect Tariff

- [ ] Hidden or disabled by default
- [ ] User enables only if relevant
- [ ] App includes it in cost calculation only when enabled
- [ ] UI explains that effect tariffs vary by grid company

Flow:

```text
Advanced
→ Enable effect tariff
→ Enter or import tariff model
→ Include in total cost
```

## Open Questions

- [x] What default retailer markup should we use?
  Answer: use `4 öre/kWh` as the default average retailer markup.
- [x] Should default grid cost be omitted or estimated nationally?
  Answer: omit grid cost by default. Add grid cost only when the user selects a DSO, enters grid fees manually, or provider/tariff data supplies it.
- [ ] Should energy tax values be bundled locally or fetched remotely?
- [x] Should the app call the product `Spotprice`, `Sprice`, or `Sparks`?
  Answer: app name is `Sprice`.
- [x] Which DSOs are worth adding as first local presets?
  Answer: use the existing DSOs currently in code for now.
- [x] Should user-entered tariff values override provider/API values?
  Answer: yes, user-entered values always win.
- [x] How visible should the confidence label be in the menu bar?
  Answer: use `Uppskattat` by default, `Anpassat` when the user has manually added cost settings, and no confidence label when provider data is connected.

## Review Fix Sprint

These items address the code review findings from the cost-profile sprint. Work through them in order and check each box as it lands.

### 1. Route Menu Bar Label Through `CostProfile`

- [x] Update `SpotPriceViewModel.State.totalPriceLabel` to use `ConsumptionSettings.shared.costProfile`
- [x] Stop passing `currentTariff` into `MenuBarLabel`
- [x] Keep the menu bar label aligned with chart, widget, and quick stats totals
- [x] Verify manual grid fees affect the menu bar label

### 2. Centralize Confidence Recalculation

- [x] Add a helper that derives `CostConfidence` from remaining profile values
- [x] Treat retailer changes, grid values, and enabled effect tariff as user-configured cost data
- [x] Preserve no-label behavior for provider-connected profiles
- [x] Use the helper instead of hand-written confidence branches where possible

### 3. Fix Retailer Reset Confidence

- [x] Update `RetailContractSection` reset action so it only resets retailer values
- [x] Keep `Anpassat` if grid fees or effect tariff remain configured
- [x] Return to `Uppskattat` only when no custom cost values remain

### 4. Fix DSO Clearing Confidence

- [x] Update `SettingsView.updateGridCompany("")` to recompute confidence after removing grid costs
- [x] Keep `Anpassat` when effect tariff remains enabled
- [x] Keep `Anpassat` when retailer values remain customized

### 5. Preserve User-Entered Grid Overrides

- [x] Track whether grid fees came from user input versus preset/imported data
- [x] Do not overwrite user-entered grid fees when changing fuse size or reselecting DSO
- [x] Allow explicit preset refresh when the user wants imported values again
- [x] Keep tariff metadata/freshness separate from manual override state

### 6. Validate Review Fixes

- [x] Run live diagnostics for changed files
- [x] Build app and widget successfully
- [x] Verify menu bar, chart, widget, and monthly views agree on total cost source
- [x] Verify confidence labels after retailer reset, DSO clearing, and effect tariff toggle

## Retail Contract Model Sprint

Goal: make `Elhandel` match what users see in real contracts. Users should enter the price model and values from their electricity agreement, while Sprice handles the internal calculation.

### Product Principle

The app should not force every user into a spot-price markup model.

- Timpris/spotpris: total follows spot price plus markup
- Rörligt månadspris: total uses the contract's current monthly öre/kWh value
- Fast pris: total uses the fixed contract öre/kWh value
- Consumption data provider: only supplies usage data unless it also supplies explicit contract cost data

### 1. Define Retail Contract Model

- [x] Add `RetailContractType`
- [x] Add `contractPriceOrePerKWh` for variable monthly and fixed contracts
- [x] Keep `retailerMarkupOrePerKWh` for spot-price contracts
- [x] Keep `retailerMonthlyFee`
- [x] Add source metadata for retail contract values if needed
- [x] Migrate existing users to `spotPriceMarkup`

Target model:

```swift
enum RetailContractType: String, Codable, Sendable {
    case spotPriceMarkup
    case variableMonthlyPrice
    case fixedPrice
}
```

### 2. Refactor Retail Cost Math

- [x] Update `TotalCostService` to calculate retail energy cost by contract type
- [x] For `spotPriceMarkup`, use `spotPrice + markup`
- [x] For `variableMonthlyPrice`, use `contractPriceOrePerKWh`
- [x] For `fixedPrice`, use `contractPriceOrePerKWh`
- [x] Continue prorating monthly fee in one place
- [x] Keep taxes/grid costs separate from retail contract cost

Calculation rules:

```text
Timpris/spotpris:
spotpris + elhandelspåslag + månadsavgift

Rörligt månadspris:
avtalat elpris + månadsavgift

Fast pris:
fast elpris + månadsavgift
```

### 3. Redesign Elhandel Settings

- [x] Replace the single markup-first section with contract type selection
- [x] Use segmented control: `Timpris`, `Rörligt`, `Fast`
- [x] Show only fields relevant to the selected contract type
- [x] Rename `Påslag` to `Elhandelspåslag`
- [x] Use `Avtalat elpris` for variable monthly price
- [x] Use `Fast elpris` for fixed price
- [x] Keep monthly fee visible for all contract types

Suggested UI:

```text
Elhandel
[ Timpris ] [ Rörligt ] [ Fast ]

Timpris:
Elhandelspåslag (öre/kWh)
Månadsavgift (kr/mån)

Rörligt:
Avtalat elpris (öre/kWh)
Månadsavgift (kr/mån)

Fast:
Fast elpris (öre/kWh)
Månadsavgift (kr/mån)
```

### 4. Explain Active Source Clearly

- [x] Show active retail contract mode in `Elhandel`
- [x] Explain that consumption data does not override manually entered retail contract values
- [x] If provider contract data becomes available later, show it as an explicit selectable source
- [x] Avoid using `påslag` copy for non-spot contracts

Copy examples:

```text
Aktivt: Eget avtal
Förbrukningsdata hämtas från datakällan, men elhandelskostnaden kommer från dina egna värden.

Timpris:
Elpriset följer spotpris plus ditt elhandelspåslag.

Rörligt:
Använd priset i öre/kWh från ditt aktuella rörliga månadspris.

Fast:
Använd ditt fasta avtalade pris i öre/kWh.
```

### 5. Update Cost Displays

- [x] Make menu bar total reflect selected retail contract type
- [x] Make chart total reflect selected retail contract type
- [x] Make widget total reflect selected retail contract type
- [x] Make monthly cost reflect selected retail contract type
- [x] Keep spot price visible even when total cost uses fixed or monthly contract price
- [x] Add wording if total cost is contract-based rather than spot-following

### 6. Validate Retail Contract Flow

- [x] Verify default first launch remains `Timpris` with 4 öre/kWh markup
- [x] Verify entering `Rörligt månadspris` makes total cost ignore hourly spot for retail energy
- [x] Verify entering `Fast pris` makes total cost ignore hourly spot for retail energy
- [x] Verify grid/tax parts still calculate normally
- [x] Verify confidence remains `Anpassat` after user enters contract values
- [x] Run live diagnostics for changed files
- [x] Build app and widget successfully

## Copy Cleanup Sprint

Tighten Swedish product language so the UI matches the actual cost model: quarter-based spot contracts, contract-based prices, and partial totals when grid costs are missing.

### Copy Cleanup Checklist

- [x] Rename user-facing `Timpris` copy to `Kvartspris`
- [x] Rename spot-following fee copy from `Elhandelspåslag` to `Elhandelsavgifter`
- [x] Ensure `påslag` copy only appears where the contract follows spot price
- [x] Clarify that `Rörligt månadspris` and `Fast pris` use the user's avtalat elpris instead of spot price
- [x] Replace vague total-price copy with wording that explains elnätskostnad is excluded until added
- [x] Update chart, callout, monthly, menu, settings, and widget copy for contract-based totals
- [x] Review breakdown labels so fixed and variable contracts do not look like spot-price calculations
- [x] Run live diagnostics for changed files
- [x] Build app and widget successfully

Suggested core copy:

```text
Kvartspris
Elhandelskostnaden följer Nord Pools spotpris per kvart.

Elhandelsavgifter (öre/kWh inkl. moms)
Använd avgifterna från ditt elhandelsavtal.

Sprice visar ett pris baserat på tillgängliga uppgifter. Elnätskostnad ingår först när du lägger till dina elnätsuppgifter.
```

## Quarter Price Product Focus Sprint

Reframe Sprice around quarter-price decisions. The chart should explain the market and timing opportunity. Non-quarter contracts should be supported as comparison inputs, not as the main chart behavior.

### Product Direction

```text
Sprice is primarily for users with, or considering, quarter-price electricity contracts.

Quarter-price users get actionable timing: what is cheap or expensive now.
Fixed and variable monthly users get comparison: how their contract relates to the market.
```

### Quarter Price Focus Checklist

- [x] Rename the primary chart concept to market quarter price, not user total cost
- [x] Keep the chart variable for `Kvartspris` users because their retail cost follows the market
- [x] For `Rörligt månadspris` and `Fast pris`, show the chart as market comparison instead of user cost variation
- [x] Add copy that explains: `Grafen visar marknadens kvartspris. Din kostnad beräknas från ditt avtal.` (already implemented via `chartMeaningText`)
- [x] Add an agreement reference line for fixed and variable contracts showing their flat contract price
- [x] Update chart callout to show both market quarter price and user's agreement price when relevant
- [x] Update quick stats labels so `Lägsta`, `Högsta`, and `Snitt` explicitly indicate whether they show market or total cost
- [x] Keep cost cards and monthly cards using the selected contract for cost calculation (already implemented)
- [x] Update quick stats section header to clarify cost vs market context (changed to "Prisspann idag")
- [x] Fix misleading "Din totalkostnad idag" label (changed to "Prisspann idag (kr/kWh)")
- [x] Clear cached consumption when switching providers (different homes/meters)
- [x] Display provider name in consumption section to clarify data source
- [x] Clear cached consumption after "Verifiera" to force fresh data load
- [x] Add debug logging to verify consumption refresh flow
- [x] Add detailed cost breakdown in chart callout showing all price components (compact: top 3 + Övrigt)
- [x] Make "Nästa kvart" show total cost for spot-following contracts, matching primary display
- [x] Remove confidence label from callout (redundant with breakdown)
- [x] Flip comparison logic for fixed/variable contracts (market higher = good choice, market lower = losing money)
- [x] Fix callout badge and color to show contract comparison for fixed/variable contracts instead of market tertiles
- [x] Fix callout text and icon to show "Sparar X%" (green) when market is higher than contract, "Förlorar X%" (red) when lower
- [x] Cache TotalCostService in ChartCalloutView to reduce object creation
- [x] Add automatic widget reload when cost profile or consumption changes
- [x] Fix widget monthly cost calculation to use hoursInPeriod: 730 for proper fee proration
- [x] Add debug logging to widget to verify costProfile values
- [x] Add UserDefaults.synchronize() before widget reads costProfile to ensure latest values
- [x] Add detailed debug logging in both widget and menubar for price comparison
- [x] Add logging for bucket time ranges to verify synchronization
- [x] Fix widget monthly cost calculation to add full monthly fees instead of prorating them
- [ ] Verify widget shows same total cost kr/kWh as menubar icon after settings change
- [ ] Verify widget shows same monthly cost as app (within estimation margin)
- [ ] Verify both use same bucket time range for current quarter
- [ ] Run live diagnostics for changed files
- [ ] Build app and widget successfully

### Future Consumption Chart

- [ ] Add a separate monthly cost-over-time chart only when consumption data exists
- [ ] Base monthly cost movement on kWh usage over time, not on spot variation for fixed contracts
- [ ] Keep market price and actual cost as separate series or separate chart modes

## Trust And Release Readiness Sprint

The release gate now lives in `Docs/trust-and-release-readiness-sprint.md`.

Use that sprint as the canonical iOS 26 readiness checklist for cost-profile trust copy, app/widget parity, local-history privacy, release logging cleanup, diagnostics, builds, and manual verification.
