# TestFlight Readiness Plan

Goal: pause feature work long enough to understand the app as a whole, align documentation with the actual implementation, and prepare a credible TestFlight build.

## Product Snapshot

- [ ] Re-read the app end-to-end as a user: macOS menu bar, iOS app, widget, settings, provider setup, history, export/delete.
- [ ] Write a concise current-product summary.
- [ ] Decide what the TestFlight build is meant to prove.
- [ ] Decide which features are intentionally beta-quality.
- [ ] Identify copy that still says old product names or outdated assumptions.

## Documentation Audit

- [ ] Update `README.md` to reflect the current iOS tabs, history, widget history cache, and local data controls.
- [ ] Review `Docs/business-case.md` for naming drift between Sparks, Sprice, and Spotprice.
- [ ] Review `Docs/historical-cost-and-consumption-plan.md` and mark remaining work accurately.
- [ ] Review `Docs/ios-app-menubar-parity-plan.md` and decide whether it should be archived as completed planning material.
- [ ] Review `Docs/ios-widget-plan.md` against current widget behavior and the missing iOS widget extension.
- [ ] Add a short privacy/data handling note for local history.

## TestFlight Product Gates

- [ ] First launch works without provider credentials.
- [ ] Current cost is visible with default estimate.
- [ ] Settings can configure price area, retail contract, and grid costs.
- [ ] Provider setup failure is understandable and non-blocking.
- [ ] History behaves sensibly with no provider, working provider, failed provider, and switched provider.
- [ ] Export and delete local history work.
- [ ] Widget shows current price/cost and cached monthly history when available.
- [ ] macOS app, iOS app, and widget all build in Xcode.

## Technical Gates

- [ ] Remove or reduce noisy debug logging.
- [ ] Verify App Group entitlements for all relevant targets.
- [ ] Verify no provider credentials are written into history records.
- [ ] Verify CloudKit is disabled for local history.
- [ ] Review privacy manifest requirements before submission.
- [ ] Decide whether background refresh recording is required for TestFlight or can wait.

## Known Non-Goals For First TestFlight

- Automated test target.
- CloudKit sync.
- Full remote tariff API.
- Manual recalculation of historical periods.
- iOS widget extension if the current TestFlight only targets the app shell.

## Definition Of Done

- Documentation matches what the app actually does.
- Remaining gaps are named and intentional.
- A tester can understand what to try, what is expected to work, and what is not part of the build yet.

