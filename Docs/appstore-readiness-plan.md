# Sprice iOS App Store Readiness Plan

**Status**: Active master plan — single source of truth for the iOS release
**Updated**: 2026-06-10 (verified against actual project state)
**Goal**: Ship Sprice for iOS (app + widget) to the App Store with zero high-risk rejection vectors.

**Scope decision**: Only the iOS app is released on the App Store. The macOS menu bar app is distributed manually outside the store and must never block the iOS release. macOS work is tracked at the bottom as non-blocking future work.

Related docs:
- `Docs/trust-and-release-readiness-sprint.md` — runtime trust gate (manual verification source for Step 4).
- `Docs/app-store-submission-and-polish-sprint.md` — packaging details (folded into Steps 5–6 here).

---

## Current Baseline (verified 2026-06-10)

**Resolved — no longer blockers**
- Deployment targets settled at iOS 26.0 / macOS 26.0. All four targets build. (The earlier advice to retarget iOS 17 is superseded; iOS 26 limits install base, which is acceptable for v1.)
- `PrivacyInfo.xcprivacy` added for all four targets declaring UserDefaults usage with reason `CA92.1`.
- App Store icon solved via Icon Composer `spotprice.icon`, which generates the 1024×1024 store icon.
- iOS widget extension target `SpotpriceAppWidgetExtension` created, builds, shares `SpotpriceWidget()` and `group.mb.Spotprice`.
- Debug logging cleaned up; no `print` or `AppLog.*.debug` in Swift sources.
- Entitlements clean: App Group only.
- No StoreKit / IAP / analytics / tracking SDKs. Local-first privacy design.
- Version 1.0 (build 1) set.

**Open gaps — the remaining work**
1. Large set of uncommitted changes on `main` (widget extension, privacy manifests, schemes).
2. `ITSAppUsesNonExemptEncryption` not declared in any target.
3. Empty leftover `AppIcon.appiconset` folders in all four targets; `ASSETCATALOG_COMPILER_APPICON_NAME = spotprice` only confirmed on 2 of 4 targets.
4. iOS app has no history deletion, no history export, no credential clearing, and no privacy/legal links (macOS has deletion; iOS needs parity).
5. No hosted privacy policy or support page.
6. `AppReviewNotes.md` describes only the macOS app — must be rewritten for the iOS submission.
7. Manual verification half of the trust sprint is unchecked (App Group data flow, fresh install, stale states, quarter boundaries, widget parity, accessibility).
8. App Store Connect record, metadata, privacy labels, and screenshots not started.

---

## Definition of Done — "iOS App Store Ready"

- [ ] All Step 1–6 checklists below complete.
- [ ] Zero FAIL items in a fresh `/appstore-review` audit run.
- [ ] Release archive of `SpotpriceApp` validates in Xcode.
- [ ] Privacy nutrition labels and review notes match actual app behavior.
- [ ] At least one internal TestFlight build smoke-tested on a real device.

## Non-Goals for v1.0

- Mac App Store submission (macOS is manual distribution).
- Automated test suite.
- CloudKit sync, IAP/subscriptions, remote Eltariff API.
- New widget families beyond `.systemSmall`.
- Major refactors of `ConsumptionSettings`, `SpotPriceViewModel`, or cost calculation.

---

## Step 1 — Commit the current baseline ✅ (2026-06-10)

Land the in-flight work so every later step has a stable base.

- [x] Review and commit the staged/modified set (widget extension target, privacy manifests, schemes, doc updates) as clean commits on `main`. (`cf0d1a8`, `a007a4d`; removed a stray `Text("test")` debug label from the widget before committing.)
- [x] Confirm schemes still build after commit (SpotpriceApp, SpotpriceAppWidgetExtension, Spotprice all build).

## Step 2 — Small compliance fixes ✅ except font licensing (2026-06-10)

- [x] Add `ITSAppUsesNonExemptEncryption = NO` to the iOS app and iOS widget Info.plists. Verified present in the built bundle.
- [x] Delete the four empty leftover `AppIcon.appiconset` folders.
- [x] Verify the icon pipeline: `CFBundleIconName = spotprice` and compiled Icon Composer layers confirmed in the built app's `Assets.car`. Widget extensions intentionally have no own icon (gallery uses the host app icon).
- [x] Info.plist values release-appropriate: app and iOS widget both display "Sprice" (fixed widget display name, was "SpotpriceAppWidgetExtension").
- [x] Remove `README.md` from all targets' Resources build phases (it was shipping inside the app bundle).
- [ ] **OPEN — font licensing**: bundled fonts are **PP Object Sans** (Pangram Pangram, © Alexander Slobzheninov, "All rights reserved"). Free for personal use only; App Store distribution requires a paid PP license (or swap to an open/system font). Decide before submission.

**Exit criteria**: met except the font licensing decision, which is tracked above and must be resolved before Step 6.

## Step 3 — iOS data controls + legal surfaces (the only real feature work)

Likely Guideline 5.1.1 rejection vector: the app stores provider credentials and local history with no iOS way to remove them.

- [ ] Add "Rensa historik" (delete local history) to iOS settings, reusing `EnergyHistoryStore` deletion used by macOS.
- [ ] Add history export (the trust sprint lists export + delete as a release gate for local history).
- [ ] Add "Koppla från leverantör" / clear credentials in `ProviderSettingsView`, and ensure stale consumption data is cleared from views and App Group cache when credentials are removed.
- [ ] Write a privacy policy (local-only storage, optional provider connections and what data leaves the device, no tracking/analytics) and host it (GitHub Pages is the fastest path).
- [ ] Host or designate a support page/contact.
- [ ] Add an "Om Sprice" / "Integritet" section in `AppSettingsView` with working links to the privacy policy and support page, plus a one-line local-data summary ("All din data stannar på enheten").

**Exit criteria**: a new user can find and use deletion controls on iOS without help; legal links open correctly.

## Step 4 — Manual verification pass (trust sprint execution)

Work through the unchecked sections of `Docs/trust-and-release-readiness-sprint.md` on an iOS 26 simulator/device. Highest-value checks:

- [ ] Fresh install with no settings shows useful estimated cost; no blocking setup states.
- [ ] iOS app writes `CostProfile`, price area, cached consumption, and widget summary to the App Group; widget reads them after fresh install, settings changes, app restart, and device restart.
- [ ] Widget kr/kWh and monthly cost match the app after settings changes; both agree on the current quarter bucket.
- [ ] Quarter boundaries `:00/:15/:30/:45`, day rollover, and foreground/background transitions update app + widget.
- [ ] No network / refresh failure / provider credential failure / partial data states are scoped and understandable, never whole-app failures.
- [ ] Estimated vs. customized vs. provider-backed values clearly distinguished; Swedish copy does not imply exact invoice matching.
- [ ] Dynamic Type and VoiceOver spot checks on dashboard, settings, history, chart callout, and widget; color states not color-only.
- [ ] Swedish formatting for currency, kWh, öre/kWh, dates.

**Exit criteria**: trust sprint manual sections checked off or known issues triaged as fix-now vs. document-as-limitation.

## Step 5 — Store packaging (App Store Connect)

- [ ] Rewrite `AppReviewNotes.md` for the iOS app: 4-tab experience, provider flows with steps, locations of privacy links and deletion controls, statement that grid/total costs are estimates. Keep the honest "estimates" framing.
- [ ] Create the App Store Connect app record: confirm final name ("Sprice"), subtitle, category.
- [ ] Swedish description, keywords (elpris, spotpris, kvartspris, elkostnad, förbrukning), promotional text. English description only if launching outside Sweden.
- [ ] Support URL + privacy policy URL (from Step 3).
- [ ] Privacy nutrition labels — should be minimal given local-only design; align with actual behavior (provider credentials stay on device, network calls only to price/provider APIs).
- [ ] Age rating questionnaire.
- [ ] Screenshots for 6.5" and 6.9" iPhones: dashboard, price chart, settings precision flow, history, widget. Realistic Swedish sample data, no real credentials, final Swedish copy, nothing implying exact invoice matching.

**Exit criteria**: every required ASC field populated; review notes final.

## Step 6 — Archive, TestFlight, submit

- [ ] Build Release configuration for `SpotpriceApp` + widget.
- [ ] Run a fresh `/appstore-review` audit; resolve FAILs, paste the summary table in the appendix below.
- [ ] Archive → Validate in Xcode; run Organizer Privacy Report on the archive and resolve issues.
- [ ] Upload to App Store Connect; install via internal TestFlight on a real device.
- [ ] Smoke test following `AppReviewNotes.md`; ideally one external tester runs the script.
- [ ] Tag `appstore-candidate-1`.
- [ ] Submit for review.

**Exit criteria**: submitted build in review.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| 5.1.1 rejection over data deletion/credentials | Medium | High | Step 3 ships deletion + export + disconnect before submission |
| Privacy policy takes longer than expected | Medium | Medium | Conservative factual policy; local-only design makes it short |
| Reviewer confusion about estimates vs. invoices | Medium | Medium | Honest review notes + in-app "estimate" labels (Step 4/5) |
| iOS 26-only target shrinks audience | Accepted | Low | Documented decision; revisit after v1 |
| Scope creep | High | High | Non-Goals enforced; one step at a time |

## macOS (non-blocking, after iOS ships)

Manual distribution will eventually need: Developer ID signing, notarization, and a download page. None of this gates the iOS release. The macOS app continues to build from the same shared code; only verify macOS still builds when shared code changes (already part of the trust sprint).

---

## Appendix: Latest Audit Summary

*(Paste the `/appstore-review` results table here after the Step 6 run.)*
