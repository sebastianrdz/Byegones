# Byegones: App Store submission checklist

Start with `docs/NEXT-STEPS.md` for the current status. Bundle ID: `app.byegones.ios`. Site: https://byegones.vercel.app. `{TEAM_ID}` comes from your developer account. Steps marked (you) need your Apple account.

## 1. Xcode signing (you)
- [ ] Xcode > Settings > Accounts: sign in with the paid Apple Developer account.
- [ ] Register the App ID `app.byegones.ios` at developer.apple.com > Identifiers (explicit, no capabilities).
- [ ] Select the PhotoCleaner target > Signing & Capabilities: tick Automatically manage signing, choose your Team (or give Claude the Team ID to set it).
- [x] Bundle ID set to `app.byegones.ios` (tests: `app.byegones.ios.tests`, `app.byegones.ios.uitests`).
- [ ] Commit the project changes (release.sh requires a clean git tree).

## 2. App Store Connect: New App (you)
- [ ] My Apps > + > New App. Platform iOS, name `Byegones`, primary language English (U.S.), bundle ID `app.byegones.ios` (appears once registered in step 1), SKU `byegones-ios`. Note the numeric Apple ID (App Store ID) for the Rate link.
- [ ] App Information > Localizable Information > add language **Spanish (Mexico)**.

## 3. Listing fields (paste from the repo)
- [ ] English: `docs/appstore/listing.en.md` (subtitle A, promotional text, description, keywords, What's New).
- [ ] Spanish (Mexico): `docs/appstore/listing.es.md`.
- [ ] Screenshots (already generated; re-run `scripts/screenshots.sh` then `scripts/frame-screenshots.sh` only after UI changes). Upload `marketing/screenshots/en/1..6.png` and `marketing/screenshots/es/1..6.png` to the 6.9" iPhone slot of each locale (1320x2868).
- [ ] Privacy Policy URL: `https://byegones.vercel.app/privacy`. Support URL: `https://byegones.vercel.app/support`. (Live and verified 2026-11-25.)
- [ ] Copyright line and contact details for App Review.

## 4. Policy and compliance answers
- [ ] Category: Photo & Video; secondary Utilities.
- [ ] Age rating: 4+ (questionnaire: all "None").
- [ ] App Privacy: Data Not Collected. Details: `docs/appstore/privacy-label.md`.
- [ ] Export compliance: see `docs/appstore/compliance.md` (standard answers; no custom encryption).
- [ ] Price: Free (no in-app purchases). Availability: choose countries.
- [ ] EU Digital Services Act trader status: declare as trader or non-trader as applies to you; see `docs/appstore/compliance.md`.
- [ ] Review the risk notes in `docs/appstore/review-risks.md`.

## 5. Build upload
- [ ] `scripts/release.sh --dry-run` shows no pre-flight failures.
- [ ] Optional API key (kept outside the repo): `export ASC_KEY_PATH=... ASC_KEY_ID=... ASC_ISSUER_ID=...`. Otherwise the Xcode account is used.
- [ ] First upload: `scripts/release.sh` (build 1; use `TEAM_ID={TEAM_ID}` if the team is not set in the project). Later uploads: `scripts/release.sh --bump`, then commit the build-number bump.
- [ ] Fallback: Xcode > Product > Archive > Distribute App > App Store Connect.
- [ ] Wait for processing; the build appears in TestFlight.

## 6. TestFlight device checklist (you)
- [ ] Install via TestFlight on a real iPhone.
- [ ] Right swipe advances; left swipe raises the trash count and MB.
- [ ] Star shows a heart (Favorites) in the Photos app.
- [ ] Undo reverts all three actions.
- [ ] Committing shows one system popup and items land in Recently Deleted.
- [ ] Cancelling the popup keeps the pile.
- [ ] After force-quit and relaunch, progress is kept.
- [ ] Videos play; iCloud-only items load.
- [ ] Spanish device language shows Spanish UI; dark mode, Reduce Motion, VoiceOver actions work.

## 7. Submit for review (you)
- [ ] Version page > Build > select the processed build.
- [ ] App Review Information: paste `docs/appstore/review-notes.md`; add your contact details (the support email shown on the website's support page).
- [ ] Add for Review > Submit. Review usually takes 24-48 hours.
- [ ] Rollback: before approval, remove the build and submit a new one. After release, upload a fixed build or remove the app from sale; there is no binary rollback.

## 8. After approval: website App Store link
Support email and developer name are already filled in. Swap the "Coming soon" pills for the live App Store link with the commands in `docs/copy/website-launch.md`, then push to `main` (Vercel auto-deploys).
