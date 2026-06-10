# Trust And Release Readiness Sprint

Goal: prepare Sprice for release without adding new verification infrastructure. Verification for this sprint is build-based, diagnostics-based, and manual on the iOS 26 deployment target.

## Scope

This sprint is the release gate for the current cost, history, widget, and iOS app work.

It covers:

- iOS 26 deployment readiness.
- App and widget build readiness.
- Entitlements and App Group data flow.
- Fresh install, upgrade, stale data, and failure scenarios.
- Quarter-boundary and date-sensitive behavior.
- Manual first-launch, settings, history, and widget validation.
- Product trust copy and release logging cleanup.
- Privacy and local-data release checks.

Store listing, screenshots, App Store metadata, and broader polish live in `Docs/app-store-submission-and-polish-sprint.md`.

It does not add new verification infrastructure.

## Current Execution Notes

- [x] Set the iOS app deployment target to iOS 26.0.
- [x] Added privacy manifests for the iOS app, macOS app, macOS widget, and iOS widget bundle declaring UserDefaults required-reason API usage with reason `CA92.1`.
- [x] Confirmed existing app and widget entitlements use `group.mb.Spotprice`.
- [x] Created and cleaned up the iOS widget target as `SpotpriceAppWidgetExtension` with product `SpotpriceAppWidgetExtension.appex`.
- [x] Reused the shared `SpotpriceWidget()` from the iOS widget bundle entry point.
- [x] Set the iOS widget scheme to request `.systemSmall`, matching the widget's current supported family.
- [x] Built the `SpotpriceApp`, `Spotprice`, `SpotpriceWidgetExtension`, and `SpotpriceAppWidgetExtension` schemes successfully after the metadata changes.
- [x] Removed release-noisy debug logging and confirmed no `AppLog.*.debug` or `print` calls remain in Swift sources.
- [x] Ran live diagnostics on changed Swift files and rebuilt the iOS app, iOS widget, and macOS menu bar schemes successfully.

## iOS 26 Deployment Readiness

- [x] Keep the iOS app deployment target at iOS 26.
- [x] Keep the iOS widget deployment target at iOS 26.
- [x] Confirm every iOS-facing view compiles against iOS 26 SDK APIs without compatibility shims for older iOS versions.
- [x] Confirm Charts usage, including `chartXSelection`, is valid for the iOS 26 deployment target.
- [x] Confirm WidgetKit usage is valid for the iOS 26 widget target.
- [x] Confirm shared SwiftUI components do not import AppKit or use macOS-only APIs when compiled into iOS targets.
- [x] Confirm shared code still builds for the macOS menu bar target when touched.

## Entitlements And App Group

- [x] Confirm the iOS app target has the expected App Group entitlement.
- [x] Confirm the iOS widget target has the same App Group entitlement.
- [x] Confirm the macOS app and widget targets still use the intended App Group entitlement.
- [x] Confirm no target has unused or broader entitlements than needed for this release.
- [ ] Verify the iOS app writes `CostProfile`, price area, cached consumption, and widget summary data to the App Group store.
- [ ] Verify the iOS widget reads the same App Group data after fresh install, settings changes, app restart, and device restart.

## Product Trust Checks

- [ ] Verify a new user sees estimated total cost without provider setup.
- [ ] Verify settings allow the user to improve precision manually.
- [ ] Verify provider setup is optional and only needed for consumption data.
- [ ] Verify effect tariff is optional and disabled by default.
- [ ] Verify estimated, customized, and provider-backed values are clearly distinguished.
- [ ] Verify Swedish trust copy does not imply exact invoice matching when data is estimated or incomplete.
- [ ] Verify missing grid fees, missing consumption, stale data, and partial history are visible where relevant.
- [ ] Verify price, cost, tax, grid, and contract labels use consistent Swedish terms across app, widget, and menu bar.

## Install And Upgrade Scenarios

- [ ] Fresh install with no settings shows useful estimated cost.
- [ ] Fresh install with no provider credentials does not show blocking setup states.
- [ ] Existing settings migrate into the current `CostProfile` shape.
- [ ] Existing App Group widget cache does not override newer app settings.
- [ ] Existing local history remains readable after app launch.
- [ ] Delete and reinstall behavior is understood and documented for local settings, history, and widget cache.
- [ ] Clearing or changing provider credentials does not leave misleading consumption data visible.

## Failure And Stale Data Behavior

- [ ] No network: app keeps usable cached or empty states without blocking navigation.
- [ ] Spot price refresh failure: user sees a clear stale or unavailable state.
- [ ] Provider credential failure: consumption views show a scoped provider issue, not a whole-app failure.
- [ ] Provider returns partial consumption: monthly/history views mark partial data clearly.
- [ ] Widget with stale cached data shows a clear stale state when appropriate.
- [ ] History read/write failure does not block the main price dashboard.
- [ ] Settings save failure, if possible, does not silently imply values were persisted.

## Time And Quarter Boundaries

- [ ] Verify current quarter selection around `:00`, `:15`, `:30`, and `:45`.
- [ ] Verify app and widget agree on the current quarter bucket.
- [ ] Verify day rollover updates current day chart, stats, and labels.
- [ ] Verify month rollover updates monthly cost, history, and summary labels.
- [ ] Verify behavior on DST-sensitive dates for Swedish local time.
- [ ] Verify foreground/background transitions do not leave the app or widget on an old quarter.

## App And Widget Parity

- [ ] Verify the iOS app and widget use the same `CostProfile` data from the App Group.
- [ ] Verify widget total cost kr/kWh matches the app after settings changes.
- [ ] Verify widget monthly cost matches the app within the documented estimation margin.
- [ ] Verify both app and widget use the same current quarter bucket.
- [ ] Verify widget refresh is triggered after cost profile or consumption changes.
- [ ] Verify widget does not require provider credentials directly.

## Privacy And Local Data

- [ ] Verify history data remains local to the device and App Group container.
- [ ] Verify history records contain no provider credentials or direct personal identifiers.
- [ ] Verify export and delete controls are available for local history.
- [ ] Review privacy copy for local history behavior.
- [ ] Review `PrivacyInfo.xcprivacy` before App Store submission if the file is added or changed.
- [ ] Keep CloudKit disabled until a separate sync sprint defines opt-in, migration, conflicts, and App Store privacy updates.

## Accessibility And Formatting Sanity

- [ ] Verify primary price, total cost, confidence, stale-state, and widget values have useful VoiceOver labels.
- [ ] Verify Dynamic Type does not clip primary dashboard, settings, history, chart callout, or widget text.
- [ ] Verify important color states are not color-only; labels or symbols explain meaning.
- [ ] Verify currency, kWh, öre/kWh, percentages, and dates use Swedish-friendly formatting.
- [ ] Verify small-screen layouts do not overlap or truncate release-critical values.

## Performance And Responsiveness

- [ ] App opens to a useful dashboard without waiting for provider or history work.
- [ ] Manual refresh does not freeze the dashboard.
- [ ] History views use summaries or bounded queries rather than scanning unnecessary raw records.
- [ ] Widget timeline generation remains cheap and does not call provider APIs.
- [ ] Background or widget refresh work does not cause repeated writes for unchanged data.

## Release Cleanup

- [x] Remove or hide debug logging that is not needed for release diagnostics.
- [x] Keep useful release diagnostics behind intentional logging categories.
- [ ] Remove stale planning comments from shipped code.
- [ ] Confirm app display name and user-facing product name are consistent.
- [ ] Confirm settings labels use final Swedish copy.
- [ ] Confirm known limitations are documented in the relevant plan before release.

## Build And Manual Verification

- [x] Run live diagnostics for changed Swift files.
- [x] Build the iOS app target successfully for iOS 26.
- [x] Build the iOS widget target successfully for iOS 26.
- [x] Build the macOS menu bar target successfully if shared code changed.
- [ ] Build release configuration for release-bound targets.
- [ ] Manually verify first launch on an iOS 26 simulator or device.
- [ ] Manually verify settings changes on an iOS 26 simulator or device.
- [ ] Manually verify widget installation and refresh on an iOS 26 simulator or device.
- [ ] Manually verify the macOS menu bar still reflects shared cost-model changes if shared code changed.

## Definition Of Done

- [x] iOS app target builds for iOS 26 with no release-blocking diagnostics.
- [x] iOS widget target builds for iOS 26 with no release-blocking diagnostics.
- [ ] Release configuration builds for release-bound targets.
- [ ] Manual validation for first launch, settings changes, provider-optional behavior, history controls, failure states, time boundaries, and widget parity passes.
- [ ] User-facing copy clearly distinguishes estimated, customized, provider-backed, stale, and partial values.
- [ ] Local history privacy behavior is documented and manually verified.
- [ ] Entitlements and App Group data flow are manually verified.
- [x] Release logging is intentional and not noisy.
- [ ] No new verification infrastructure remains in this sprint scope.
