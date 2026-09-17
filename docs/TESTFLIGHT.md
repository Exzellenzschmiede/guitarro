# TestFlight checklist

Everything below runs on your Mac with your Apple Developer account. Nothing is uploaded automatically.

## One-time setup

1. **App Store Connect:** create the app (bundle id `de.kaniut.guitarro`, or change it in
   `Config/Signing.xcconfig` and `project.yml`). Under *Monetization -> In-App Purchases* create:
   - Subscription group "Guitarro Pro" with `de.kaniut.guitarro.pro.monthly` (1 month) and
     `de.kaniut.guitarro.pro.yearly` (1 year, optional 7-day free trial)
   - Non-consumable `de.kaniut.guitarro.pro.lifetime`
   The product ids must match `StoreManager.ProductID`. Fill in localized names, prices and a review screenshot.
2. **Signing:** run `Scripts/bootstrap.sh`, then put your Team ID into `Config/Signing.xcconfig`.
3. **Privacy:** in App Store Connect answer the nutrition labels with "Data not collected". The app
   uses microphone and camera on device only; the optional AI coach sends chat text to Anthropic when
   the player enters their own API key. Set the age rating to 4+.
4. **Legal:** publish a privacy policy and terms page and put the URLs into the paywall strings
   `pro.legal` in `Guitarro/Resources/Localizable.xcstrings`.

## Every build

```bash
Scripts/release.sh            # build number = timestamp
Scripts/release.sh 42         # explicit build number
```

The script archives in Release, exports with `Config/ExportOptions.plist` (method
`app-store-connect`, destination `upload`) and uploads. Processing takes 5–20 minutes, then the build
shows up under TestFlight. Add internal testers (up to 100, no review) or external testers (needs
a short beta review).

## Testing in-app purchases

- In Xcode the scheme uses `Config/Guitarro.storekit`, so purchases work in the simulator without
  App Store Connect. Use *Debug -> StoreKit -> Manage Transactions* to reset.
- In TestFlight builds purchases run in the sandbox: testers are not charged.
- Debug builds have "Pro simulieren" in the profile to unlock everything without buying.

## What reviewers look for

- Microphone and camera usage strings (already localized in `InfoPlist.xcstrings`).
- Restore-purchases button (present on the paywall) and clear subscription terms.
- No placeholder content: replace the story or song content only with material you have rights to.
