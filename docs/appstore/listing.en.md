# App Store listing (EN)

App name: **Byegones** (chosen at Gate 1, subtitle A). EN is the primary locale; ES targets Spanish (Mexico), reusable for Spanish (Spain).

## Name
`Byegones` (8 chars; see `names.md`)

## Subtitle options (<= 30)
- A. `Swipe away photo clutter` (24)
- B. `Swipe to keep or delete` (23)
- C. `Free up space, one swipe` (24)

**Recommended: A.**

## Promotional text (<= 170)
Clean up your camera roll in minutes. Swipe left to delete, right to keep, up to favorite. Free, private, and nothing is deleted until you confirm.

(147 chars)

## Description (<= 4000)
```text
Your camera roll, one swipe at a time.

Byegones turns photo cleanup into a quick game: swipe left to delete, swipe right to keep, swipe up to favorite. Free, no account, and your photos never leave your iPhone.

SWIPE. DECIDE. DONE.
- Newest photos and videos first, one at a time, full screen
- Left to delete, right to keep, up (or tap the star) to keep and add to Favorites in Photos
- Videos play muted and loop; tap to turn sound on
- See the date, the size and the length of each item

NOTHING IS DELETED UNTIL YOU SAY SO
- Swiped-left items go into a trash pile, not into the void
- Open the pile any time, tap a photo to take it out
- See how many items are in the pile and how much space they take up
- Delete everything in one go with a single confirmation from iOS

MADE FOR MISTAKES
- Undo takes back your last decision: keep, delete or favorite
- Your progress is saved, so photos you have already reviewed do not come back
- Want a fresh start? Reset progress from Settings

PRIVATE BY DESIGN
- No account, no sign-up, no ads
- No tracking, no analytics, no data collected
- Your photos and videos stay on your iPhone. Byegones has no servers to send them to.
- Works with limited access too: share only some photos and Byegones cleans just those.

HOW IT WORKS
1. Allow access to your photos.
2. Swipe through your library and sort it your way.
3. Open the trash pile, check it, and tap Delete.
4. Done. Your items move to the Recently Deleted album in Photos.

GOOD TO KNOW: GETTING THE SPACE BACK
When you delete photos on iPhone, iOS keeps them in Recently Deleted for 30 days. Storage is fully freed once that album is emptied. To get the space back right away, open Photos > Albums > Recently Deleted > Select > Delete All. Byegones reminds you after every cleanup.

FREE, FOR REAL
No in-app purchases, no subscriptions, no trials.
```

## Keywords (<= 100, comma-separated, no spaces)
```text
cleaner,storage,camera,gallery,videos,screenshots,declutter,tidy,organize,trash,favorites,private
```
(97 chars)

Strategy: name and subtitle are already indexed by Apple, so none of their words are repeated (checked below). Singular/plural pairs are not both listed. No competitor names, no third-party trademarks. Roughly 3 characters are left unused; tune after launch data exists. "Camera roll" intent is covered by `camera` plus the word `roll` inside the name.

**Overlap check** (keywords vs name `Byegones` and all three subtitle options):
```text
keywords: cleaner, storage, camera, gallery, videos, screenshots, declutter, tidy, organize, trash, favorites, private
name+subtitle words: away, clutter, delete, free, keep, one, or, photo, byegones, space, swipe, to, up
intersection: (none)
duplicates within keywords: (none)
spaces inside keyword string: none
```
Name is final (Byegones); re-check only if it changes.

## What's New (1.0)
Welcome to Byegones! Swipe through your photos and videos, build a trash pile, and delete it all in one go. Undo is always one tap away. Free, private, no account.

(163 chars)

## Screenshot captions (<= 30 chars; in shot order)

| # | Caption | chars | Screen to capture |
|---|---|---|---|
| 1 | Swipe. Keep. Delete. Done. | 26 | Swipe screen: card mid-swipe with DELETE stamp, bottom button row visible |
| 2 | See what you'll clear | 21 | Trash pill ("12 · 340 MB") plus the trash review sheet grid |
| 3 | Oops? Undo it | 13 | Swipe screen right after Undo: card flying back, Undo button highlighted |
| 4 | Swipe up to favorite ★ | 22 | Card swiped up with the blue FAVORITE stamp |
| 5 | Private. On your iPhone. | 24 | Onboarding page 2 ("Your photos never leave your iPhone") |
| 6 | Nice work. Pile cleared! | 24 | Celebration screen ("You cleared X MB" + lifetime total) |

## Character-count verification (python `len()`)

| Field | Count | Limit | Result |
|---|---|---|---|
| Subtitle option A | 24 | 30 | OK |
| Subtitle option B | 23 | 30 | OK |
| Subtitle option C | 24 | 30 | OK |
| Promotional text | 147 | 170 | OK |
| Description (with Byegones) | 1852 | 4000 | OK |
| Description (name replaced by 30 chars, worst case) | 1940 | 4000 | OK |
| Keywords | 97 | 100 | OK |
| What's New 1.0 | 163 | 4000 | OK |
| Caption 1 | 26 | 30 | OK |
| Caption 2 | 21 | 30 | OK |
| Caption 3 | 13 | 30 | OK |
| Caption 4 | 22 | 30 | OK |
| Caption 5 | 24 | 30 | OK |
| Caption 6 | 24 | 30 | OK |

## Accuracy notes
- Deleted items go to Recently Deleted for 30 days; the copy says so and shows how to empty it. No instant-space claim.
- Per-item size depends on a guarded Photos API; if it is unavailable, remove the size mentions (description bullet "date, size and length", caption 2) before submitting.
- No ratings, download counts, rankings, awards or competitor comparisons are claimed.
