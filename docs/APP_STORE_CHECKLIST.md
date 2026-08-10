# App Store / App Review readiness checklist

Derived from master specification §118. Completing this list improves release readiness; it does **not** guarantee App Store approval.

## Build & quality

- [ ] App compiles with the **Release** configuration
- [ ] No warnings that indicate real defects (unused incorrect APIs, deprecated security paths, etc.)
- [ ] No placeholder API keys or secrets in the binary / source shipped to review
- [ ] No demo credentials in production builds
- [ ] Core flows tested offline where appropriate (logging, persistence, local coach fallback)

## Legal & privacy

- [ ] Privacy Policy URL works (public HTTPS) — replace `AppIdentity.privacyPolicyURLPlaceholder`
- [ ] Terms of Use URL works — replace `AppIdentity.termsURLPlaceholder`
- [ ] Permission usage strings match actual features (camera, optional HealthKit share)
- [ ] Privacy Manifest (`PrivacyInfo.xcprivacy`) complete for accessed APIs
- [ ] App Privacy disclosures in App Store Connect match reality
- [ ] Account deletion works **if** accounts exist (document N/A if fully local-only)

## Commerce

- [ ] Restore Purchases works
- [ ] Subscription description is accurate
- [ ] Free trial clearly disclosed (length + price after trial)
- [ ] Product IDs match App Store Connect and `CoachingConfig.coachProductID`

## Content & UX

- [ ] No dead links in Settings / paywall / legal screens
- [ ] Screenshots contain no debug UI, placeholders, or lorem content
- [ ] No inaccessible buttons or empty actions presented as finished features
- [ ] No fake nutrition database claims (bundled/mock catalog must be labeled honestly)

## Notes for reviewers (optional App Review notes)

- Explain that coaching math is on-device; AI is explanatory via a backend proxy when configured.
- Explain HealthKit is optional and not required for subscription value.
- Provide a sandbox Apple ID path for subscription testing if requested.
