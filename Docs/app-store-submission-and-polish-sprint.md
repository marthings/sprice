# App Store Submission And Polish Sprint

Goal: prepare Sprice for App Store submission after the trust and release readiness gate is healthy.

This sprint covers store packaging, submission metadata, screenshots, final assets, signing/archive checks, and broader polish. It should not block the product trust sprint unless it discovers a release-critical runtime issue.

## Scope

This sprint covers:

- App Store Connect metadata.
- Screenshots and preview assets.
- App icons, display names, and bundle metadata.
- Signing, archive, and upload readiness.
- Privacy labels and support links.
- Deeper accessibility, formatting, and performance polish.

Runtime trust checks remain in `Docs/trust-and-release-readiness-sprint.md`.

## App Store Metadata

- [ ] Confirm final app name, subtitle, and category.
- [ ] Write Swedish App Store description.
- [ ] Write English App Store description if launching outside Sweden.
- [ ] Prepare keywords focused on electricity price, spot price, quarter price, consumption, and cost tracking.
- [ ] Prepare support URL.
- [ ] Prepare privacy policy URL.
- [ ] Prepare marketing URL only if needed.
- [ ] Document known limitations honestly, especially estimates and provider coverage.

## Privacy Labels And Review Notes

- [ ] Align App Store privacy answers with actual local-only history behavior.
- [ ] Document that history is stored locally unless a future sync feature is added.
- [ ] Document provider credential handling at a high level for App Review.
- [ ] Document why App Group storage is used by app and widget.
- [ ] Document any network calls made to price or provider APIs.
- [ ] Confirm there are no analytics, ads, or third-party tracking SDKs unless explicitly added later.

## Assets And Screenshots

- [ ] Confirm final app icon renders correctly in all required sizes.
- [ ] Confirm widget preview/icon assets render correctly.
- [ ] Capture iPhone screenshots for first launch/dashboard, price chart, settings precision flow, history, and widget.
- [ ] Capture iPad screenshots only if iPad is included in the release.
- [ ] Avoid screenshots that imply exact invoice matching for estimated costs.
- [ ] Use realistic Swedish sample data without exposing real credentials or personal data.
- [ ] Verify screenshots use final Swedish copy.

## Bundle, Version, And Signing

- [ ] Confirm bundle identifiers for iOS app and widget.
- [ ] Confirm version and build number are set for submission.
- [ ] Confirm display name is final.
- [ ] Confirm required app capabilities match entitlements.
- [ ] Confirm no unused entitlements remain.
- [ ] Create a Release archive for the iOS app.
- [ ] Validate archive before upload.
- [ ] Upload archive to App Store Connect.

## Required Files And Metadata

- [ ] Confirm `Info.plist` values are release-appropriate.
- [ ] Confirm required privacy usage descriptions exist if protected APIs are used.
- [ ] Confirm `PrivacyInfo.xcprivacy` exists if required by used APIs or dependencies.
- [ ] Confirm fonts are bundled and licensed for release.
- [ ] Confirm no local debug files or development-only resources are shipped.

## Broader Accessibility Polish

- [ ] Review VoiceOver order for dashboard, settings, history, and widget.
- [ ] Review Dynamic Type across common sizes.
- [ ] Review contrast for confidence labels, chart callouts, stale states, and warnings.
- [ ] Review tap targets in settings and dashboard cards.
- [ ] Review reduced motion behavior if animations are added.

## Broader Performance Polish

- [ ] Inspect cold launch responsiveness on a physical device if available.
- [ ] Inspect dashboard refresh responsiveness after provider credentials are configured.
- [ ] Inspect history screen responsiveness with a larger local dataset.
- [ ] Inspect widget timeline generation cost.
- [ ] Remove excessive release logging discovered during profiling.

## Submission Definition Of Done

- [ ] Trust and release readiness sprint is complete or has no known release blockers.
- [ ] App Store metadata is complete.
- [ ] Privacy answers and review notes match actual app behavior.
- [ ] Screenshots are captured with final copy and realistic non-personal data.
- [ ] Release archive validates successfully.
- [ ] App is uploaded to App Store Connect.
