# Byegones: next steps (handoff)

Status as of 2026-11-25. The app is code-complete and QA-approved. The website is live. **What remains is the Apple account setup, the first upload, and App Store submission.**

## Where things stand

| Area | State |
|---|---|
| App | Byegones (internal target `PhotoCleaner`), bundle ID `app.byegones.ios`, version 1.0.0, build 1 |
| Tests | 124 unit and 21 UI tests passing (two consecutive runs on a freshly erased simulator); Release build compiles |
| QA | SHIP WITH FIXES; every fix has landed. Deferred to v1.1: grabbing a card mid-snap-back keeps its momentum (needs a spring integrator), plus low-risk items R3, R6, R8, R10 and R11 |
| Website | https://byegones.vercel.app (EN/ES landing, `/privacy`, `/support`). Every push to `main` auto-deploys `website/` |
| Store assets | 12 screenshots (EN/ES, 1320x2868) in `marketing/screenshots/`; listing copy in `docs/appstore/listing.{en,es}.md` |
| Repo | https://github.com/sebastianrdz/Byegones (public), branch `main` |

## A. Apple setup (you, about 10 minutes)

1. **Sign in to Xcode:** Xcode > Settings > Accounts > + > Apple ID, using the paid developer account.
2. **Register the bundle ID:** [developer.apple.com/account](https://developer.apple.com/account) > Certificates, IDs & Profiles > Identifiers > + > App IDs > App.
   - Description: `Byegones`
   - Explicit Bundle ID: `app.byegones.ios`
   - No extra capabilities needed.
3. **Create the app record:** [App Store Connect](https://appstoreconnect.apple.com) > Apps > + > New App.
   - Platform: iOS
   - Name: `Byegones`
   - Primary language: English (U.S.)
   - Bundle ID: `app.byegones.ios`
   - SKU: `byegones-ios`

   If App Store Connect says the name is taken, the fallbacks screened in `docs/appstore/names.md` are Shoo, Fewer and Ligero.
4. **Collect two values for the next session:**
   - **Team ID:** 10 characters, from the developer.apple.com > Membership page.
   - **App Store ID:** the numeric "Apple ID" under App Information in App Store Connect.

## B. Next session (Claude, once A is done)

1. Set `DEVELOPMENT_TEAM = <Team ID>` on the app target in `PhotoCleaner.xcodeproj/project.pbxproj`. Signing is automatic.
2. Replace `{{APP_STORE_ID}}` in `PhotoCleaner/App/AppConfig.swift`. It feeds the Settings "Rate Byegones" link.
3. Commit and push. `release.sh` needs a clean tree, and the push also redeploys the site.
4. Run `scripts/release.sh --dry-run`, then `scripts/release.sh`. That archives with `-allowProvisioningUpdates`, so Xcode creates the certificate and profile, then exports and uploads. The first upload keeps build 1, so no `--bump` is needed.
5. Confirm the build appears in App Store Connect > TestFlight after processing, usually 10 to 30 minutes.

If upload fails with "No suitable application records", the App Store Connect record from A.3 is missing, or its bundle ID doesn't match.

## C. Before submitting (you)

- **TestFlight on a real iPhone:** run the device checklist in `docs/appstore/checklist.md` section 6. Nothing has run on a physical device yet. iCloud-only photos, Limited library access, the change observer and haptics are only verified in the simulator.
- **App Store Connect fields:** follow `docs/appstore/checklist.md` sections 2 to 4 and 7. That covers the listing (EN plus Spanish (Mexico)), screenshots, privacy and support URLs, category, 4+ age rating, "Data Not Collected", export compliance, and pasting `docs/appstore/review-notes.md`.
- **Open risks:**
  - [ ] **Trademark:** run a USPTO and EUIPO clearance search on "Byegones" (classes 9 and 42). The screening so far is in `docs/appstore/names.md`.
  - [ ] **Privacy policy:** get a legal review of the draft text (`docs/legal/`). It is live on the website.
  - [ ] **EU DSA trader status:** declare it in App Store Connect (`docs/appstore/compliance.md`).
  - [ ] **File size:** the size readout uses an undocumented `PHAssetResource` key, a guideline 2.5.1 risk. It is kept for v1 (rationale in `docs/appstore/review-risks.md` row 1). If App Review objects, delete `PhotoLibrary.byteSize(for:)` and resubmit.
  - [ ] **Motion review (optional):** run `/review-animations` yourself for a formal motion sign-off. The substitute audit passed after fixes.

## D. After approval

- Swap the website's "Coming soon" pills for the live App Store link. The perl commands are in `docs/copy/website-launch.md`. Pushing to `main` deploys it.

## Handy commands

```sh
# Tests (erase and re-seed the simulator first; the delete tests consume photos)
xcrun simctl erase <udid> && xcrun simctl boot <udid> && scripts/seed-uitest-photos.sh <udid>
xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'id=<udid>' -parallel-testing-enabled NO

# Release
scripts/release.sh --dry-run
scripts/release.sh

# App Store screenshots (already final; re-run only after UI changes)
scripts/screenshots.sh && scripts/frame-screenshots.sh

# Manual website deploy (normally automatic on push); run from the repo root
npx vercel@latest deploy --prod --scope sebastianrdzs-projects
```

Disk note: simulators and derived data filled the disk once. Delete `build/` subfolders and any extra simulators after big test runs.

## Resume prompt for the next session

> Continue the Byegones App Store release. Read `docs/NEXT-STEPS.md`. I finished the Apple setup in section A: Team ID `<…>`, App Store ID `<…>`. Do section B, then run `scripts/release.sh` to upload.
