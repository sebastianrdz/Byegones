# Team Context Brief: Byegones (internal target name: PhotoCleaner)

**What:** A free iPhone app for cleaning up the camera roll, Tinder-style.
- Swipe left: the item goes to the trash pile.
- Swipe right: keep.
- Swipe up, or tap ★: keep and set `isFavorite` in Photos.
- Undo reverts the last decision.

Deletes are **batched**: one "Delete N items" action triggers the single iOS system confirmation. Items load newest first. Languages are EN and ES. It's built for the App Store, has no IAP, and collects no data (fully on-device).

**Authorities.** Read these before working:
- `PRODUCT.md` (product truth)
- `DESIGN.md` (visual system, once WP1 delivers it)
- `/Users/sebastian/.claude/plans/want-to-create-a-mighty-crescent.md` (the full plan: app spec, screens, work packages)

**Stack:**
- SwiftUI, iPhone only, portrait, iOS 17+.
- Liquid Glass (`glassEffect`) on iOS 26, with an `.ultraThinMaterial` fallback.
- Swift 6 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- No third-party dependencies.
- Xcode 26.6 / iOS 26.5 SDK. The simulator runtime is downloading, and no signing identity exists yet.

**Paths:**
- `PhotoCleaner.xcodeproj`: hand-written pbxproj with a synced root group.
- `PhotoCleaner/{App,Library,Session,Views,Resources}`
- `PhotoCleanerTests/`
- `docs/appstore/`, `docs/legal/`, `docs/copy/`
- `website/`
- `scripts/`
- `marketing/`

**Commands:**
- Build:
  `xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- Test (needs the simulator runtime):
  `xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

**Constraints:**
- Stay inside your package's folders. Other agents are working in parallel.
- No fabricated stats, reviews, or competitor claims.
- Never write the user's name, email, or other personal info into files. Use placeholders: `{SUPPORT_EMAIL}`, `{BUNDLE_PREFIX}`. The app name is **Byegones** (user-facing); replace `{AppName}` with it.
- Don't commit. The orchestrator commits.

**Output contract.** Return:
- **STATUS:** done / partial / blocked
- **DELIVERABLES:** the files changed, with their paths
- **VERIFICATION:** the commands you ran and their actual output
- **DECISIONS:** the choices you made and why
- **RISKS / OPEN ITEMS**

Return raw findings, not a narrative.
