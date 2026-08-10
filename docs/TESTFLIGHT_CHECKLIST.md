# TestFlight & release process checklist

Derived from master specification §119. Insert **your** real Apple account, team, and product values — do not invent certificates or developer IDs.

## 1. Xcode signing

- [ ] Open `MyCoach.xcodeproj`
- [ ] Select target **MyCoach** → Signing & Capabilities
- [ ] Enable **Automatically manage signing**
- [ ] Choose your **Team**
- [ ] Confirm bundle ID is unique to you (default placeholder: `com.company.mycoach`)

## 2. Bundle identifier

- [ ] Finalize reverse-DNS bundle ID
- [ ] Update Xcode `PRODUCT_BUNDLE_IDENTIFIER`
- [ ] Update test bundles (`com.… .tests`, `com.… .uitests`) if the app ID changes
- [ ] Align any URL schemes / AppIdentity placeholders

## 3. App Store Connect app creation

- [ ] Create a new iOS app with the same bundle ID
- [ ] Set name, primary language, SKU
- [ ] Complete age rating and export compliance answers truthfully

## 4. StoreKit product creation

- [ ] Create an auto-renewable subscription group (e.g. “Coach AI”)
- [ ] Create monthly product ID matching code: `com.company.mycoach.coach.monthly` (or your replacement)
- [ ] Localizations: display name + description
- [ ] Price tier for your markets

## 5. Introductory free trial

- [ ] Configure **14-day** free introductory offer on the monthly product
- [ ] Verify paywall copy discloses trial length and renewing price
- [ ] Cross-check `MyCoach/Resources/StoreKit/MyCoach.storekit` for local parity

## 6. Privacy information

- [ ] Fill App Privacy questionnaire
- [ ] Host Privacy Policy + Terms; paste URLs into App Store Connect and the app
- [ ] Confirm Privacy Manifest matches declared API usage

## 7. App metadata

- [ ] Description, keywords, support URL, marketing URL
- [ ] Screenshots for required device sizes (no debug content)
- [ ] App icon (replace empty `AppIcon` slot)

## 8. Archive & upload

- [ ] Product → Archive (Release)
- [ ] Distribute to App Store Connect
- [ ] Wait for build processing to finish

## 9. Internal TestFlight

- [ ] Add internal testers
- [ ] Install build; verify onboarding, food log, subscription purchase/restore
- [ ] Test StoreKit sandbox purchases with a sandbox Apple ID

## 10. External TestFlight

- [ ] Submit beta for Beta App Review if required
- [ ] Add external groups / public link as needed
- [ ] Collect feedback on coaching flows and offline behavior

## 11. App Review submission

- [ ] Select build, complete version metadata
- [ ] Provide review notes (optional HealthKit explanation, subscription test account)
- [ ] Submit for App Review

**Reminder:** following this checklist does not guarantee approval. Resolve rejection feedback concretely if Apple requests changes.
