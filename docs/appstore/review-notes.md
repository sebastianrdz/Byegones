# Notes for App Review (paste into App Store Connect)

> DRAFT: fill `Byegones` before pasting. Character count is checked in the report.

---
Thank you for reviewing Byegones.

NO LOGIN: There are no accounts, no sign-in, no network calls, no analytics, no ads and no in-app purchases. The app is free and works fully offline.

WHAT IT DOES: It lets users clean up their own Photos library by reviewing photos and videos one at a time, newest first. Swipe left (or tap Delete) puts the item in a trash pile. Swipe right (or tap Keep) keeps it. Swipe up (or tap the star) keeps it and marks it as Favorite in Photos. Undo reverts the last decision.

HOW TO TEST:
1. Launch. Three onboarding pages explain the gestures and privacy. The last page explains why Photos access is needed, then shows the standard iOS permission prompt.
2. Allow access to Photos. The test device or simulator needs some photos and videos in its library. If the library is empty, the app shows an empty state.
3. Swipe a few cards left, right and up. Every action also has an on-screen button and a VoiceOver action.
4. Tap the trash pill at the top. The review sheet shows a grid of the pending items. Tap an item to remove it from the pile.
5. Tap "Delete N items". The app makes ONE batched PhotoKit delete request, so iOS shows its single system confirmation for the whole batch. Nothing is deleted before this confirmation. If the user cancels, nothing is deleted and the pile stays.

RECENTLY DELETED: Deleted items move to the Photos Recently Deleted album, where iOS keeps them for 30 days. The review sheet states this. Space is fully reclaimed only after that album is emptied. The app does not claim instant storage savings.

PERMISSIONS: Photos access (read/write) is used only to display items, set Favorite, and delete items the user chose. Limited access is supported: the app works with the selected subset and shows a banner to change the selection. If access is denied, the app shows an explanation and an Open Settings button; nothing is blocked or repeatedly prompted.

DATA: Nothing leaves the device. Local storage only: a small file with Photos identifiers of reviewed and pending items plus a lifetime "space freed" total, and a UserDefaults onboarding flag. Settings > Reset progress clears the review history.

FILE SIZE: Item size shown on cards is read from the asset's PhotoKit resource metadata, guarded so it cannot crash. If a size cannot be determined, the size badge is simply hidden and the app works normally.

REVIEW PROMPT: After the first cleanup of 100 MB or more, the app may call the system SKStoreReviewController rating prompt once the cleanup completes. It is never forced.

Support: https://byegones.vercel.app/support  Privacy: https://byegones.vercel.app/privacy
---
