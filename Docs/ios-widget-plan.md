# iOS Widget Plan

Goal: make the existing Spotprice widget available for the iOS app while keeping shared data, models, services, and widget UI reusable.

## Current State

- The existing `SpotpriceWidgetExtension` is embedded in the macOS menu bar app target, `Spotprice`.
- The iOS app target, `SpotpriceApp`, now has a separate widget extension target: `SpotpriceAppWidgetExtension`.
- The iOS widget product is `SpotpriceAppWidgetExtension.appex` with bundle identifier `mb.SpotpriceApp.SpotpriceWidget`.
- The iOS widget bundle reuses the shared `SpotpriceWidget()` entry point and currently supports `.systemSmall`.
- Shared widget data is read through `UserDefaults(suiteName: "group.mb.Spotprice")` via `ConsumptionSettings`.
- The iOS app and iOS widget target both use the `group.mb.Spotprice` App Group entitlement.
- Remaining readiness work is manual App Group data-flow and widget refresh verification on iOS 26.

## Recommended Approach

Create a separate iOS widget extension target that reuses the existing widget source files and shared code.

This is safer than trying to make the existing macOS widget extension serve both host apps, because extension bundle identifiers and embed relationships are tied to the host app target.

## Implementation Status

- [x] Added iOS Widget Extension target `SpotpriceAppWidgetExtension`.
- [x] Removed the unused Live Activity template file.
- [x] Cleaned target, product, entitlement, and scheme naming.
- [x] Pointed the iOS widget bundle at the shared `SpotpriceWidget()`.
- [x] Set the iOS widget scheme to run `.systemSmall`.
- [x] Built the iOS widget target on an iOS 26 simulator.
- [ ] Manually add the widget to the Home Screen and verify live spot price data.
- [ ] Verify app settings changes refresh the iOS widget through the App Group data flow.

## Step-by-Step

1. Add a new Widget Extension target in Xcode for iOS.
   - Suggested target name: `SpotpriceAppWidgetExtension`.
   - Deselect Live Activity unless we explicitly want it.
   - Deselect Configuration App Intent unless we add configurable widget choices.

2. Set the iOS widget extension bundle identifier.
   - Suggested value: `mb.SpotpriceApp.SpotpriceWidget`.
   - Keep it under the iOS app bundle identifier `mb.SpotpriceApp`.

3. Add the existing widget files to the iOS widget target membership.
   - `SpotpriceWidget/SpotpriceWidget.swift`
   - `SpotpriceWidget/SpotpriceWidgetBundle.swift`
   - `SpotpriceWidget/Assets.xcassets`
   - `SpotpriceWidget/Info.plist`, or a separate iOS widget plist if needed.

4. Add required shared files to the iOS widget target membership.
   - `Shared/Models`
   - `Shared/Services`
   - `Shared/Providers`
   - `Shared/DesignSystem`
   - Any small shared components/configuration referenced by the widget.

5. Add App Group entitlements to the iOS app target.
   - Create or assign an entitlements file for `SpotpriceApp`.
   - Enable `group.mb.Spotprice`.

6. Add App Group entitlements to the iOS widget extension target.
   - Use the same group: `group.mb.Spotprice`.

7. Verify shared settings flow.
   - The iOS app should write `ConsumptionSettings.costProfile`, `cachedConsumption`, and `priceArea` into the App Group defaults.
   - The iOS widget should read those values from the same App Group defaults.

8. Check widget-supported families.
   - Current widget supports `.systemSmall`.
   - Keep `.systemSmall` first for parity.
   - Add `.systemMedium` later only after designing a proper layout.

9. Build and manually verify on iOS 26.
   - Build the iOS app target with deployment target iOS 26.
   - Build the iOS widget extension target with deployment target iOS 26.
   - Run on an iOS 26 simulator or device.
   - Add the widget to the Home Screen and verify it shows live spot price data.

## Notes

- The widget should not depend on Keychain credentials directly. It should continue to use cached consumption/settings data written by the app.
- If the iOS app has no settings UI yet, the widget may show spot price data but not personalized consumption/cost data until the app writes the shared settings.
- Keep macOS-specific app UI out of shared code. The widget UI can stay shared only as long as it remains valid for both macOS and iOS WidgetKit.
