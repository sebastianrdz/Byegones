# Design: {AppName}

<!-- impeccable:design-schema 1 -->
Platform: ios (SwiftUI, iPhone portrait, iOS 17+, Liquid Glass on iOS 26). Mode: Operate (a repeated task), with an Experience core (the photo is the interface). Authority: `PRODUCT.md`. This file is the visual contract for every screen. Where this file and Apple's HIG disagree on structure or navigation, the HIG wins; this file owns color, type, materials, motion and the per-screen composition.

Name rule: the app name is undecided. Use `{AppName}`; never "PhotoCleaner" and never the name of any dating app in user-facing strings.

## 1. Direction

**Thesis: color is a verb.** The UI is quiet and neutral so the photo is the loudest thing on screen. The only saturated color in the app is action color (keep green, delete red, favorite blue, undo amber) and it appears at the moment of a decision: on the stamp, on the button glyph, on the confetti. Everything else is ink, paper and glass.

**Own-world, with all content removed:** a warm paper canvas (near-black in dark mode) holding one big rounded photo card with a white hairline-thin lift shadow; four glass buttons below it whose glyphs are the four action colors; one indigo (the icon's color) as the single brand tint for the primary call to action and links. SF Pro Rounded gives numbers and headings a friendly, "game score" voice; SF Pro carries all reading text.

**Joyful but restrained.** Delight budget, in order: (1) the card physics, (2) the stamp reveal during a drag, (3) the count-up and one-time confetti burst after a successful delete, (4) the looping demo card in onboarding. Everything else is static or uses system transitions. Nothing else animates.

**Refuses:** the category default of a bright gradient background with floating blobs; a custom nav bar; stacked identical cards of icon + title + text; gradient text; decorative blur; progress rings as filler; emoji as icons; a fake "X people cleaned Y GB" stat.

**Why light and dark both:** the use scene is a person on a couch or commute, any ambient light. Follow system appearance; never force one. Dark mode is the reference for photo viewing (the canvas recedes to near-black), light mode is tuned warm so photos do not look clinical.

## 2. Color tokens

Define every token as a Color Set in `Assets.xcassets` with Any/Dark appearances (and a High Contrast variant where noted). Reference by asset name; no raw hex in views. Names are `Color("name")` / `Color.name` via an extension.

### 2.1 Neutrals

| Token (asset name) | Light | Dark | Role |
|---|---|---|---|
| `canvas` | `#F6F4F0` | `#0C0C0F` | Screen background behind the card. |
| `surface` | `#FFFFFF` | `#1B1B20` | Sheets, grouped rows, empty-state placeholders, pre-photo card fill. |
| `surfaceRaised` | `#FFFFFF` | `#26262D` | Grid cell placeholder, banners. |
| `hairline` | `#17161B` @ 12% | `#FFFFFF` @ 14% | Separators, glass fallback stroke. |
| `ink` | `#17161B` | `#F5F4F8` | Primary text and symbols. |
| `inkSecondary` | `#5A5861` | `#A9A7B2` | Secondary text. |
| `inkTertiary` | `#6E6C75` | `#8D8B96` | Captions, placeholders. Never for essential info. |
| `inkFill` | `#17161B` | `#F5F4F8` | Rare solid ink surfaces. |
| `scrim` | `#000000` @ 55% | `#000000` @ 60% | Gradient under metadata on the photo. Same in both modes. |

### 2.2 Brand

| Token | Light | Dark | Role |
|---|---|---|---|
| `AccentColor` (brand, "Indigo") | `#4A3FD1` | `#A8A2FF` | Primary CTA fill, links, toggles, focus. The only non-action color. |
| `onAccent` | `#FFFFFF` | `#0C0C0F` | Text/glyph on `AccentColor` fill. |

Set `AccentColor` in the asset catalog so system controls (Toggle, links, ProgressView, nav bar buttons) inherit it.

### 2.3 Action semantics

Two values per action. `*Glyph` is for symbols and text on `canvas`/`surface`. `*Fill` is a solid fill that carries white (or dark) text, used by stamps and the Delete button label. Fills are identical in both appearances because stamps sit on photos of arbitrary brightness.

| Action | `*Glyph` light | `*Glyph` dark | `*Fill` (both) | Text on fill |
|---|---|---|---|---|
| Keep (swipe right) | `keepGlyph` `#12803F` | `#3DDC84` | `keepFill` `#12803F` | `#FFFFFF` |
| Delete (swipe left) | `deleteGlyph` `#C8202F` | `#FF6B72` | `deleteFill` `#C8202F` | `#FFFFFF` |
| Favorite (up, ★) | `favoriteGlyph` `#1B62D6` | `#5AA2FF` | `favoriteFill` `#1B62D6` | `#FFFFFF` |
| Undo | `undoGlyph` `#A35C00` | `#FFB84D` | `undoFill` `#F2A22B` | `#1F1300` |

Also define `onFill` = `#FFFFFF` and `onUndoFill` = `#1F1300`. Stamps use fills; button glyphs use `*Glyph`. Increased Contrast: darken light glyphs by ~10% and lighten dark glyphs by ~10% via the High Contrast variant.

Color is never the only signal: every action also has a distinct symbol and a text label (stamp words, VoiceOver names). Red/green are separated by symbol (`xmark` vs `checkmark`) and by position (left vs right).

### 2.4 Contrast (WCAG 2.x, computed)

All text and symbol pairs below meet AA (4.5:1 text, 3:1 non-text). Verified numerically.

| Pair | Light | Dark |
|---|---|---|
| `ink` on `canvas` | 16.4 | 17.8 |
| `inkSecondary` on `canvas` | 6.4 | 8.2 |
| `inkSecondary` on `surface` | 7.0 | 7.2 |
| `inkTertiary` on `canvas` | 4.7 | 5.8 |
| `keepGlyph` on `canvas` | 4.6 | 11.0 |
| `deleteGlyph` on `canvas` | 5.2 | 7.1 |
| `favoriteGlyph` on `canvas` | 5.1 | 7.5 |
| `undoGlyph` on `canvas` | 4.7 | 11.4 |
| `keepGlyph` / `deleteGlyph` on `surface` (dark) | n/a | 9.6 / 6.2 |
| White on `keepFill` / `deleteFill` / `favoriteFill` | 5.0 / 5.7 / 5.6 | same |
| `onUndoFill` on `undoFill` | 8.7 | 8.7 |
| `onAccent` on `AccentColor` | 7.2 | 8.6 |
| `AccentColor` as text/link on `canvas` | 6.5 | 8.6 |
| White on `scrim` over worst-case white photo | 5.7 | 5.7 |

Rule that produces these numbers: bars and buttons sit on `canvas`, not on the photo (see 8.3), so glyph contrast is deterministic. Text that must sit on a photo (metadata, duration chip) always sits on `scrim` or on a solid/material chip, never bare.

## 3. Typography

Two voices. **SF Pro (default design)** for all reading text. **SF Pro Rounded (`.design(.rounded)`)** for display moments and numerals: counter, trash pill, stamps, celebration number, onboarding titles, primary button labels. No third-party font. All sizes via text styles so Dynamic Type works; custom display sizes use `@ScaledMetric(relativeTo:)`.

| Role | SwiftUI | Design | Notes |
|---|---|---|---|
| Hero number (celebration) | `.system(size: 72, weight: .bold, design: .rounded)` via `@ScaledMetric(relativeTo: .largeTitle)` | rounded | `.monospacedDigit()`, `.contentTransition(.numericText())`, `minimumScaleFactor(0.6)`. |
| Onboarding title | `.largeTitle.weight(.bold)` | rounded | Center-aligned, max 3 lines, `.balanced` via `.multilineTextAlignment(.center)`. |
| Screen title (Trash, Settings) | `.largeTitle` / `.headline` inline | default | System large-title nav behavior. |
| Stamp word | `.title2.weight(.heavy)` | rounded | UPPERCASE via `.textCase(.uppercase)`, tracking +1.5 pt. |
| Counter / trash pill | `.subheadline.weight(.semibold)` | rounded | `.monospacedDigit()`. |
| Button label (primary) | `.headline` | rounded | |
| Body | `.body` | default | 17 pt base. |
| Secondary / helper | `.subheadline` | default | `inkSecondary`. |
| Metadata (date) | `.subheadline.weight(.semibold)` | default | White on scrim. |
| Metadata (size, duration) | `.footnote.weight(.medium)` | rounded | `.monospacedDigit()`. |
| Caption | `.caption` | default | 12 pt min; never below 11. |

Dynamic Type rules: the top bar and bottom bar switch to their compact fallback at `.accessibility1` and up: counter text hides its label ("of N") and keeps the number; bottom button glyphs scale with `@ScaledMetric` but the buttons stay 56/72 pt minimum and the bar wraps to two rows only if width runs out (it will not at 393 pt). Titles must never truncate: allow multiple lines. Spanish runs about 25 percent longer than English; layouts must tolerate that without clipping.

## 4. Layout scales

**Spacing (pt), 4-based:** `xxs 2, xs 4, s 8, m 12, l 16, xl 24, xxl 32, huge 48`. Screen gutter is `l` (16). Card gutter is `m` (12). Vertical rhythm: tight inside a group (`s`), generous between groups (`xl`), more space above a heading than below (`xl` above, `s` below).

**Corner radii (pt), continuous style (`RoundedRectangle(cornerRadius:style: .continuous)`):**

| Token | Value | Use |
|---|---|---|
| `radiusCard` | 36 | Swipe card, next card. Concentric with device corners at a 12 pt inset. |
| `radiusSheet` | system | Sheets use the system radius; do not override. |
| `radiusCell` | 14 | Trash grid cells. |
| `radiusChip` | capsule | Pills, chips, banners, buttons. |
| `radiusBanner` | 20 | Limited-access banner. |

**Hit targets:** 44 x 44 pt minimum everywhere; the four action buttons are 56 and 72 pt. Add `.contentShape` where the visible glyph is smaller than the target.

**Elevation:** only the card casts a shadow: `color .black @ 0.18 light / 0.5 dark, radius 24, y 10`. Glass and chips have none beyond the system's. No zero-offset colored glows.

## 5. Materials: Liquid Glass and the fallback

Glass is a specific effect, not decoration. It is used in exactly **four** groups, all of them controls floating over or beside the photo:

1. The four bottom action buttons.
2. The top bar: gear, counter capsule, trash pill.
3. The video mute button and duration chip on the card.
4. The limited-access banner and the iCloud-downloading chip.
Sheets and lists use system materials, never custom glass. The celebration CTA is solid accent, not glass.

Never glass: the card itself, the photo, text blocks, the onboarding pages, list rows, the trash grid.

**One helper, one place.** Engineering writes a single `glassSurface(in:interactive:)` view modifier. All four groups call it.

```swift
extension View {
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.hairline, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
        }
    }
}
```

**iOS 26:** group adjacent glass controls in one `GlassEffectContainer(spacing: 16)` so the four buttons render and morph as a set. The trash pill gets `.interactive()`. Buttons are `.interactive()`. Do not tint glass with action color (it kills legibility); the action color lives in the glyph.

**iOS 17 to 25 fallback (exact):** fill `.ultraThinMaterial`; stroke `hairline` 0.5 pt inside; shadow `.black @ 10%`, radius 8, y 2; shape identical to the glass shape. Pressed state: scale 0.94, spring response 0.25, damping 0.8.

**Reduce Transparency / Increased Contrast:** replace glass and material with solid `surface` + `hairline` stroke 1 pt. Check `@Environment(\.accessibilityReduceTransparency)`.

**Scrim:** a `LinearGradient` from `.clear` to `scrim`, bottom 140 pt of the card, behind the metadata. This is a legibility device, not glass.

## 6. Iconography (SF Symbols)

SF Symbols only, weight `.semibold`, rendering mode `.monochrome` unless noted, scaled with Dynamic Type via `Image(systemName:)` in `Label` or `.font`.

| Meaning | Symbol | Notes |
|---|---|---|
| Keep | `checkmark` | In 72 pt button, glyph 30 pt, `.bold`. |
| Delete | `xmark` | Same size as Keep. Not `trash`: the trash is the pile, the swipe is a "no". |
| Favorite | `star.fill` | 24 pt glyph in 56 pt button. Stamp uses `star.fill`. |
| Undo | `arrow.uturn.backward` | 22 pt glyph in 56 pt button. |
| Trash pill | `trash` | 15 pt, in pill. Becomes `trash.fill` when the pile is non-empty. |
| Video badge | `video.fill` | 12 pt. |
| Muted / unmuted | `speaker.slash.fill` / `speaker.wave.2.fill` | |
| Play (autoplay off) | `play.fill` | 28 pt on material circle. |
| iCloud download | `icloud.and.arrow.down` | |
| iCloud failed | `exclamationmark.icloud` | |
| Privacy (onboarding 2) | `lock.shield.fill` `.hierarchical` | 88 pt, `AccentColor`. |
| Photos permission (onboarding 3) | `photo.on.rectangle.angled` `.hierarchical` | 88 pt, `AccentColor`. |
| Limited access | `photo.badge.checkmark` | |
| Denied | `photo.badge.exclamationmark` | |
| Settings | `gearshape` | |
| Close sheet | system `xmark` in `.toolbar` Cancel/Done | Use system buttons. |
| Celebration | `checkmark.circle.fill` | 56 pt, `keepGlyph`, in ring only if needed; otherwise omit. |
| All caught up | `sparkles` | 44 pt, `.hierarchical`, `inkSecondary`. |

## 7. Motion

**Principle:** the card is a physical object. It follows the finger one to one, carries momentum when released, and returns with weight when undone. Nothing else moves unless the person caused it. All animation is spring-based, interruptible, and driven by gesture state. No linear or ease-in-out for gestures. No looping decoration except the onboarding demo.

### 7.1 Drag (gesture follows finger, no animation)

- Offset = `translation` 1:1 on both axes (vertical capped to `-height * 0.5` upward, `+40` downward with rubber-band, as down is not an action).
- Rotation (degrees) = `translation.width / 20`, clamped to +/- 15. (The brief's "width/20".)
- Decision progress `p = clamp(|dx| / 110, 0, 1)` horizontally; for up, `p = clamp(-dy / 120, 0, 1)` when `|dy| > |dx|`.
- Stamp opacity = `p`; stamp scale = `0.88 + 0.12 * p`; the opposite stamp stays at 0.
- Next card: scale `0.94 + 0.06 * p`, y offset `14 * (1 - p)`, opacity 1. A third card is never drawn.
- Commit when released with `p >= 1` **or** the predicted end translation passes 0.35 of card width horizontally (or 0.30 of height up). Otherwise snap back.

### 7.2 Fly-off (commit)

- Target: x = `sign * (cardWidth * 1.5)`, keeping the current y plus `predictedEnd.dy * 0.4`; for up, y = `-(cardHeight * 1.2)`. Rotation continues to `sign * 22` degrees.
- Spring: `.interpolatingSpring(mass: 1, stiffness: 170, damping: 24, initialVelocity: vx / distance)`; settle target about 0.30 s. Velocity-aware: a faster flick takes less time.
- Button-triggered commits use the same spring with `initialVelocity: 0`, plus a 0.08 s head start so the stamp reaches full opacity first (stamp fades in over 0.08 s with `.easeOut`).
- At landing: advance queue, the next card becomes front with no extra animation (it is already at scale 1 by `p`).

### 7.3 Snap-back (cancel)

- `.spring(response: 0.38, dampingFraction: 0.72)` on offset, rotation, stamp opacity and next-card scale together. One slight overshoot, no wobble.

### 7.4 Undo

- The last card re-enters from the side it left (up for favorite) at that exit transform, then returns to center: `.spring(response: 0.46, dampingFraction: 0.78)` with rotation easing back to 0. The current card drops to the "next card" slot at the same time with the same spring.
- The matching stamp is shown at full opacity at the start and fades to 0 over the return, so the person sees what is being reverted.
- If undoing a favorite, the star button briefly shows its inactive state (no animation; just state).

### 7.5 Everything else

| Moment | Motion |
|---|---|
| Trash pill count change | `.contentTransition(.numericText())`, default `.snappy`. |
| Button press | Scale 0.94, `.spring(response: 0.25, dampingFraction: 0.8)`. |
| Sheet present/dismiss | System. |
| Onboarding page change | System `TabView` page transition; no custom parallax. |
| Onboarding demo card | Looping 7 s sequence (see 9.1). The one decorative loop. |
| Celebration | Count-up from 0 to the number over 0.9 s (`numericText`), then one confetti burst (14 to 18 small rounded rectangles in action colors, each falls with a 1.4 s `.easeOut` and fades; plays once; never repeats). |
| Video mute toggle | Icon cross-fade 0.15 s, plus 0.6 s fade of a center hint glyph. |
| Trash grid remove | Cell shrinks 1.0 to 0.8 and fades, 0.2 s, grid reflows with `.snappy`. |
| Everything not listed | No animation. |

### 7.6 Reduce Motion (`accessibilityReduceMotion`)

- Drag still follows the finger (that is direct manipulation), but rotation is 0 and the next-card scale/offset stays fixed.
- Fly-off is replaced by a 0.18 s cross-fade: the card fades out in place, the next card is already visible beneath.
- Undo is a 0.18 s cross-fade in.
- Snap-back is a 0.15 s `.easeOut` to origin, no overshoot.
- Onboarding demo does not loop; it cross-fades between three still states every 2.5 s, and stops after one full pass.
- Confetti is removed; the number appears without count-up.
- Page transitions use the system default (which already respects the setting).

### 7.7 Haptics map (`.sensoryFeedback`, one per event, never stacked)

| Event | Feedback |
|---|---|
| Drag crosses decision threshold (p reaches 1, each direction) | `.impact(weight: .light)` once, again if crossed back out |
| Keep committed | `.impact(weight: .light, intensity: 0.6)` |
| Delete committed (to pile) | `.impact(weight: .medium)` |
| Favorite committed | `.success` |
| Undo | `.impact(flexibility: .rigid, intensity: 0.5)` |
| Snap-back | none |
| Remove an item from the pile | `.selection` |
| Delete confirmed by the system and succeeded | `.success` |
| User cancels the system confirmation | none |
| Delete failed | `.error` |
| Permission denied screen action, settings toggles | system defaults only |

Haptics follow the system "System Haptics" switch automatically; do not add a custom toggle.

## 8. Screens

Reference device: iPhone 16/17 Pro class, 393 x 852 pt. Layouts use safe areas; the numbers below are for that class and must scale for 375 pt (SE-size, if supported) and 440 pt (Pro Max) by letting the card fill available space.

### 8.1 Onboarding (3 pages, `TabView(.page)` with the system page dots, indicator hidden; a custom 3-dot row only if the system dots collide with the CTA)

Common: `canvas` background. Content centered; the visual (top 55 percent), then title, then body, then CTA pinned to the bottom with `huge` clearance from the home indicator. Title `.largeTitle.weight(.bold)` rounded, body `.body` `inkSecondary`, max width 320 pt. Primary button: full-width capsule, height 56, fill `AccentColor`, label `.headline` rounded `onAccent`. Secondary text button below (`.subheadline`, `AccentColor`) only where noted. Skip is not offered: the flow is three taps.

**Page 1: "Swipe to decide".** Visual: the animated demo card (abstract gradient "photo": sunset sky with two hills, not a real photo), 240 x 320, `radiusCard`, shadowed, on `canvas`, with a muted card peeking behind. Loop (total 7 s, spring physics from 7.1 to 7.3): idle 0.6 s, drifts right with rotation, KEEP stamp reveals, flies off, a fresh card rises into place; repeat left with DELETE; repeat up with ★ FAVORITE; rest 0.8 s. A small caption row under the card names the current gesture ("Right: keep", "Left: delete", "Up: favorite") with the matching glyph in action color, swapping with `.contentTransition(.opacity)`. Reduce Motion: see 7.6. CTA: "Next".
- States: static first frame renders if the animation has not started (no blank card).

**Page 2: "Private by design".** Visual: `lock.shield.fill` 88 pt, hierarchical, `AccentColor`, centered over a soft concentric ring of `hairline` (two circles, 160 and 220 pt, 1 pt stroke). Title: "Your photos never leave your iPhone." Body: one sentence on no account, no network, no tracking. CTA: "Next".

**Page 3: "Allow access" (pre-permission).** Visual: `photo.on.rectangle.angled` 88 pt, hierarchical, `AccentColor`. Title says what the permission is for; body explains Limited access works too and that nothing is deleted until the person confirms a final review. CTA: "Allow Photos Access" which triggers `requestAuthorization(for: .readWrite)`. Secondary button: "Not now" which still leads to the Permission-denied screen (8.2), not a dead end. This page must appear before the system prompt so the prompt never surprises.
- Edge: on iPad-sized text (accessibility sizes) content scrolls vertically; the CTA stays pinned with `safeAreaInset(edge: .bottom)`.

### 8.2 Permission states (full-screen takeovers on `canvas`, not sheets)

**Not determined:** the onboarding page 3 is this state. If the person lands on the swipe screen undetermined (e.g., skipped onboarding in a future build), show the same layout as page 3.

**Denied / restricted:** centered `photo.badge.exclamationmark` (`inkSecondary`, 64 pt), title "Photos access is off" (`.title2.weight(.semibold)` rounded), body one sentence of what it needs, primary button "Open Settings" (`UIApplication.openSettingsURLString`), no secondary. Restricted (parental controls) swaps the body to say access is restricted by the device and hides the button. Re-check authorization on `scenePhase == .active` and swap in the swipe screen automatically.

**Limited:** the app works normally. A **limited banner** sits directly under the top bar: glass capsule, `radiusBanner`, height 44, icon `photo.badge.checkmark`, text "Showing selected photos" + trailing "Change" in `AccentColor` (button opens `presentLimitedLibraryPicker`). Dismissable once per session via a trailing close affordance only if height remains; it re-appears next launch. In Settings, a row "Photos access" shows state and links to the picker or Settings.
- Edge: Limited with zero selected items shows the **All caught up** empty state variant with the "Change selection" primary button.

### 8.3 Swipe screen (the product)

Background `canvas`. No navigation bar; a custom top bar is allowed here because the screen is a single immersive task (not a hierarchy). The bottom bar is not a tab bar; navigation is Settings (gear in the top bar) and the trash pile (pill).

**Vertical stack (top to bottom):**
1. **Top bar**, 44 pt tall, `l` gutter, below the safe-area top plus 4 pt. Three items, left to right: **gear** (44 pt glass circle, `gearshape`, opens Settings), **counter capsule** (centered, glass, height 36, `.subheadline.weight(.semibold)` rounded: `{reviewed}` bold + `of {total}` in `inkSecondary`; reviewed of total in this session's snapshot, never invented), and the **trash pill** (glass, interactive, height 44, `trash` + `{count} · {size}`, e.g. "12 · 340 MB", tabular numerals). With count 0 the pill collapses to a 44 pt circle with the `trash` glyph in `inkSecondary`.
2. **Card area**: fills the space between the top bar (12 pt gap) and the bottom bar (16 pt gap), inset 12 pt each side. Card `radiusCard` 36, aspect `fill` with the photo cropped to the card (not aspect-fit) for visual fullness; a **Fit** is never offered in v1. Shadow per section 4. Cards are always portrait-shaped regardless of source ratio: landscape photos are center-cropped (faces first: use the Photos-provided crop when available).
3. **Bottom bar**: four glass buttons in a `GlassEffectContainer`, centered, spacing 16: **Undo** 56, **Delete** 72, **Favorite** 56, **Keep** 72, bottom clearance `m` above the home-indicator safe area. Glyphs use `*Glyph` colors. Because the bar sits on `canvas` (not on the photo) glyph contrast is as listed in 2.4. Undo is disabled when `history` is empty: glyph at 35 percent opacity, trait `.notEnabled` (disabled controls are exempt from contrast rules).

**Stamps** (over the card, on the front card only): rounded rectangle, `RoundedRectangle(cornerRadius: 14)`, 4 pt border in the action `*Fill`, fill the action `*Fill`, text `onFill`, `.title2.weight(.heavy)` rounded uppercase, padding 16 x 8, shadow `.black @ 0.25 r 8 y 2` so it separates from busy photos. Position: **KEEP** top-left, rotated -12 degrees (card drag right reveals it); **DELETE** top-right, rotated +12 degrees; **FAVORITE** (with `star.fill` and the word "FAVORITE") top-center, rotation 0. Inset 28 pt from card edges. Stamp text is localized and may wrap to two lines in Spanish: let the stamp grow.
Stamp opacity and scale follow 7.1. Stamps are decorative for VoiceOver (`accessibilityHidden(true)`).

**Next card peeking:** the next card renders directly behind the front, scale 0.94, y offset +14 pt (visible as a 14 pt lip at the bottom and 6 pt on the sides), `radiusCard` scaled, **no photo preview below 0.94 until `p > 0`**: it shows the real next photo, loaded from the preload cache (3 ahead), because a gray placeholder undermines the "inviting" feeling. If the next photo is not ready, show a `surface` card.

**Metadata overlay** (on the front card, bottom): scrim 140 pt, padding `l`. Line 1: date, e.g. "Mar 14, 2025" (`.subheadline.weight(.semibold)`, white). Line 2: file size and, for video, duration: "4.2 MB" and "0:14" separated by " · " (`.footnote.weight(.medium)` rounded, white at 85%). If the size key is unavailable (see the plan's 2.5.1 guard), the size is omitted without leaving an empty gap. Overlay hides during an active drag past `p > 0.3` to keep stamps readable (fade 0.15 s).

**Video treatment:** a video card shows its poster instantly, then plays **muted, looping, no controls**. Top-left `video.fill` chip (glass capsule, 12 pt symbol) is the only visible video affordance. Bottom-right: a 44 pt glass mute button (default muted, `speaker.slash.fill`); tapping the card toggles mute (tap anywhere on card also toggles, so VoiceOver gets an explicit button). A 3 pt progress hairline sits at the very bottom edge of the card, white at 40 percent track and 90 percent fill. Playback pauses when the card is dragged, when the app is inactive, and for non-front cards; only the front card plays. Autoplay is disabled when `UIAccessibility.isVideoAutoplayEnabled` is false or Low Power Mode is on: show `play.fill` on a 56 pt `ultraThinMaterial` circle that starts the video on tap.

**iCloud/network states:** a glass chip (`icloud.and.arrow.down` + "Downloading") at the card center while full-res loads; a low-res thumbnail shows beneath it. Download failure: card shows `surface` + `exclamationmark.icloud` + "Couldn't load this photo" with a text button "Skip"; the item remains swipeable (Keep, Delete, Favorite all work) without a thumbnail.

**Edge states:**
- **Loading first batch:** two skeleton cards in `surface` (no shimmer; static), counter shows a `ProgressView` in place of numbers.
- **Empty library / queue exhausted ("All caught up"):** centered `sparkles` (`inkSecondary`, 44 pt), title "All caught up" (`.title2.weight(.semibold)` rounded), body with lifetime reviewed count only if > 0, primary button "Review trash (N)" if the pile is non-empty, else a quiet "Reset progress" text button (links to Settings) — never both as primary. The bottom bar is hidden in this state; the top bar stays.
- **Last card:** no special treatment; the next-card slot is simply empty.
- **Pile non-empty at launch:** the trash pill is populated immediately.
- **Delete failed or cancelled at the system prompt:** the pile stays intact; a banner row in the sheet explains (see 8.4).

**VoiceOver:** the front card is one accessibility element: label is date, media type, size and duration ("Photo, March 14, 2025, 4.2 MB"). Custom actions: **Keep, Delete, Favorite, Undo** (Undo only when available). Buttons carry labels "Keep", "Delete", "Favorite", "Undo". Announcements: "Moved to trash. 12 items." / "Kept." / "Favorited." / "Undone." through `AccessibilityNotification.Announcement`. The trash pill is a button labeled "Trash, 12 items, 340 megabytes".

### 8.4 Trash review sheet

Presented from the pill as a **medium and large detent sheet** (`.presentationDetents([.medium, .large])`, drag indicator visible), system sheet material, `canvas` content background. Do not build a custom modal.

- **Header:** system inline navigation title "Trash" with a "Done" button (leading none; trailing `Done`). Under it, a summary row: `{N} items` + `{size}` in `.title3.weight(.semibold)` rounded, `.monospacedDigit()`.
- **Grid:** `LazyVGrid` with 3 adaptive columns (min 100 pt), spacing 4 pt, cells square (`aspectRatio(1)`), `radiusCell` 14, photo cropped to fill. Each cell: video gets the `video.fill` chip bottom-leading with duration. Tap removes the item from the pile (haptic `.selection`, cell shrinks 1.0 to 0.8 and fades, then the grid reflows) with an inline Undo toast (a capsule "Removed · Undo", glass, bottom, 4 s) because accidental taps must be reversible. No selection mode; the grid is the pile.
- **Footer (pinned, `safeAreaInset(edge: .bottom)`):** a note in `.footnote` `inkSecondary`: "Deleted items stay in Recently Deleted for 30 days." (EN/ES by the copy package), then the destructive primary button: full-width capsule, height 56, fill `deleteFill`, label "Delete {N} items" in `.headline` rounded white. This is the one place red is a button fill. The system confirmation follows; do not add our own confirmation dialog.
- **States:** empty (`trash` symbol 44 pt `inkSecondary`, "Nothing in the trash" body "Swipe left on photos you want to remove", button hidden); deleting (button shows `ProgressView` and is disabled; grid dimmed to 60 percent); cancelled at the system prompt (nothing changes; no error); failed (an inline row in `deleteGlyph` with `exclamationmark.triangle.fill` and the recovery sentence, plus the button reads "Try again"). Large pile (hundreds): grid is lazy; thumbnails are 150 pt-target `PHCachingImageManager` images.
- **Dynamic Type:** header summary wraps; button label may wrap to two lines.

### 8.5 Celebration (after a successful delete)

Presented after `commitTrash` succeeds, as a `fullScreenCover` (the sheet dismisses first), `canvas` background, no navigation chrome.

- **Layout, vertically centered:** `checkmark.circle.fill` 56 pt in `keepGlyph`; hero line **"You freed {X} MB"**: the number `.system(size: 72, weight: .bold, design: .rounded)` (scaled) with the unit `.title2.weight(.semibold)` rounded, stacked on baseline; below, `.body` `inkSecondary`: "{N} items moved to Recently Deleted." then a second line `.subheadline` `inkSecondary`: "{lifetime total} freed in total." (only if the lifetime stat is greater than this session's). Add a one-line honest note: "Space is fully reclaimed once Recently Deleted is emptied." Primary button "Keep cleaning" (accent, 56 pt) returns to the swipe screen; if the queue is empty, it reads "Done".
- **Motion:** per 7.5 once (count-up plus one confetti burst). `requestReview()` is called after the first cleanup of 100 MB or more, 0.8 s after the cover appears; never from a button, never twice.
- **Variants:** if the delete removed fewer than 1 MB or size is unavailable, show the item count as the hero ("12 items cleared") and omit the MB line. No fake stats; every number is from the session or persisted state.
- **VoiceOver:** the hero is one element ("You freed 340 megabytes"); confetti is hidden from accessibility.

### 8.6 Settings / About

Pushed as a sheet from the gear (`NavigationStack` inside a `.large` sheet), title "Settings" inline, system `List` with `.insetGrouped` style (no bespoke cards). Row order:

1. **Section Progress:** "Space freed so far" row (value, `.monospacedDigit()`, from the lifetime stat; hidden when 0); "Reset progress" destructive-role button row (`deleteGlyph` text), opens a system `confirmationDialog` ("Reset progress? Photos will show up for review again. Nothing is deleted.") with a destructive "Reset" button and Cancel.
2. **Section Photos:** "Photos access" row with current state and chevron to Settings or the limited picker.
3. **Section About:** "Privacy Policy" link row (opens in `SFSafariViewController`), "Support" link row (opens Safari to the support page), "Version" value row (`CFBundleShortVersionString (CFBundleVersion)`), and a footer in `.footnote` `inkSecondary`: "{AppName} works entirely on your iPhone. No account, no tracking."
- **States:** reset confirm; link failures use the system. No toggles in v1 (nothing to configure).
- **Footer credit:** none. No claims, no ratings.

## 9. Component notes for engineering

**ActionButton** (`Undo/Delete/Favorite/Keep`): `Button` with `glassSurface(in: Circle(), interactive: true)`, symbol per section 6, `*Glyph` foreground, `.contentShape(Circle())`, press style per 7.5, `.sensoryFeedback` per 7.7, `accessibilityLabel` per 8.3.

**Primary CTA** (`PrimaryButtonStyle`): capsule, height 56, `AccentColor` fill, `onAccent` label, pressed: opacity 0.85 + scale 0.98. Destructive variant uses `deleteFill` with `onFill` text. Disabled: opacity 0.4 with `.notEnabled`.

**Card stack:** `ZStack` of at most two cards. Gesture is `DragGesture(minimumDistance: 6)` attached to the front card; the card, its stamps and its overlay share one drag state struct. Provide VoiceOver custom actions and button taps through the same `decide(_ action:)` path as the gesture.

**Appearance:** `AccentColor` and all color sets in `Assets.xcassets`; provide Any/Dark/High-Contrast variants where section 2 requires. Never read `colorScheme` to branch hex values.

**Localization:** all strings in String Catalog; stamp words, button labels and the trash pill pattern ("{count} · {size}") are localized. Use `ByteCountFormatter` / `.formatted(.byteCount(style: .file))` for sizes so MB/GB and decimal separators are locale-correct.

## 10. Do and don't

Do: let the photo be the loudest thing; use action color only for action; keep bars on `canvas`; reuse system sheets, lists, dialogs; test at `.accessibility3`, Spanish, dark mode, Reduce Motion and Reduce Transparency.
Don't: tint glass with color; put text on a bare photo; add a tab bar; add a second brand color; add animation not in section 7; invent numbers; ship without the fallback path (iOS 17 to 25).
