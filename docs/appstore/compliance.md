> **DRAFT — attorney review required before use.** Not legal advice. Based on the app specification (no code exists yet). ASC form wording changes over time; check each answer against the live form.

# App Store compliance answers

## 1. Age rating (App Information > Age Rating)

Apple's current questionnaire (revised 2025, ratings 4+, 9+, 13+, 16+, 18+). Answer every question as follows.

| Question | Answer | Why |
|---|---|---|
| Parental Controls (in-app) | No | None. |
| Age Assurance | No | None. |
| Unrestricted Web Access | No | No web views or browser. The Settings links open Safari outside the app. |
| User-Generated Content | No | Users do not share or publish anything; photos are the user's own, shown only to them. |
| Messaging and Chat | No | None. |
| Advertising | No | None. |
| Profanity or Crude Humor | None | |
| Horror/Fear Themes | None | |
| Alcohol, Tobacco, or Drug Use or References | None | |
| Mature/Suggestive Themes | None | |
| Sexual Content or Nudity | None | App's own content has none. See note. |
| Graphic Sexual Content and Nudity | None | |
| Cartoon or Fantasy Violence | None | |
| Realistic Violence | None | |
| Prolonged Graphic or Sadistic Realistic Violence | None | |
| Guns or Other Weapons | None | |
| Medical or Treatment Information | None | |
| Health or Wellness Topics | None | |
| Simulated Gambling | None | |
| Contests | None | |
| Gambling (real money) | No | |
| Loot Boxes | No | |

**Expected rating: 4+.** Note: the app displays whatever is in the user's own library, which Apple does not treat as app content. No age gate is needed. Do not set a higher rating to "be safe"; it only shrinks the audience.

## 2. Export compliance

- Set in Info.plist: `ITSAppUsesNonExemptEncryption` = `NO` (Boolean).
- Why: the app contains no encryption of its own, makes no network connections, and links no third-party crypto. Any cryptography used by the OS (file protection, PhotoKit/iCloud transfers done by the system) is Apple's and falls under the exemption for encryption in the operating system. Answering NO means no export documentation upload and no annual self-classification report in the US for this app, and skips the per-build export question in TestFlight/ASC.
- Re-evaluate if: you add any custom crypto (CryptoKit hashing/encryption of user data for storage or transmission), your own networking, or an SDK that does.
- France: with NO, no French encryption declaration is needed. [Attorney to confirm for worldwide distribution.]

## 3. Content rights

ASC question: "Does your app contain, show, or access third-party content?" Recommended answer: **No.**
Reason: the app shows only the user's own on-device library. It bundles no licensed images, music, fonts, video or text from third parties. If the designer adds stock imagery, third-party fonts or sound effects (other than system ones), switch to **Yes** and keep license records. Confirm with designers that onboarding demo art is original.
Also confirm no bundled assets use Apple trademarks or Apple UI artwork outside permitted usage (see review-risks.md).

## 4. EULA

Recommend **Apple's standard Licensed Application End User License Agreement** (default; no custom EULA field to fill). Reasons: free, no accounts, no UGC, no data, no subscriptions; a custom EULA adds legal surface with no benefit. Use a custom EULA only if the business needs liability or warranty terms beyond Apple's, an arbitration clause, or if monetization is added. That choice requires an attorney and a named jurisdiction. Note: Apple's standard EULA already contains a disclaimer; consider adding a short non-binding "deleted items go to Recently Deleted for 30 days" note in-app (already planned), which is a stronger protection against "I lost my photos" complaints than legal text.

## 5. EU Digital Services Act (DSA) trader status

ASC: App Store Connect > Business > Compliance (or Agreements, Tax, and Banking > Compliance). Declaration is per developer account, required to keep distributing in the EU.

| Situation | Choose | Consequences |
|---|---|---|
| Developer acts in a trade, business, craft or profession (e.g. a company, a sole proprietor monetizing, an app that is part of a business or portfolio, or a free app used to promote other paid products/services) | **Trader** | Provide address, phone and email; Apple displays them on the app's EU product page. Apple verifies the details. Consumer-law obligations (EU) apply, such as responding to consumer complaints. If you do not complete it, the app is removed from EU storefronts. |
| Individual acting purely for personal, non-commercial reasons (free hobby app, no income, no promotion of a business) | **Not a trader** | No contact details shown; the app is described as from a non-trader and EU consumer-protection rules for traders may not apply. Misdeclaring is a compliance risk. |

Judgment: **unknown; the user must decide.** Notes. Being on a paid developer account does not by itself make someone a trader, but repeated publishing, any monetization now or later, or a company-registered account usually points to trader. If trader and you do not want a home address public, use a business address and a dedicated phone number or email. **Requires attorney review** before choosing "Not a trader".
Placeholders: `{TRADER_ADDRESS}`, `{TRADER_PHONE}`, `{SUPPORT_EMAIL}`.

## 6. Privacy manifest (`PrivacyInfo.xcprivacy`)

Recommended file, placed in the app target (Resources) and included in Copy Bundle Resources:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Engineer checks (not legal calls, but they decide whether the manifest is complete):
- `CA92.1` = reading/writing UserDefaults for the app's own functionality. Correct for the onboarding flag.
- Add `NSPrivacyAccessedAPICategoryFileTimestamp` with `C617.1` **only if** code reads file creation/modification dates (e.g. `FileManager.attributesOfItem`, `URLResourceValues.contentModificationDate`) of files inside the app container. Plain JSON read/write does not need it.
- Add `NSPrivacyAccessedAPICategoryDiskSpace` (`E174.1`) only if free disk space APIs are called. The spec does not use them (bytes freed is the app's own counter).
- Do not call `systemUptime`/`mach_absolute_time` for non-display purposes without declaring `NSPrivacyAccessedAPICategorySystemBootTime`.
- Run Xcode's Product > Archive > Generate Privacy Report and compare before submitting.

## 7. Photos purpose string (`NSPhotoLibraryUsageDescription`, guideline 5.1.1)

Review: purpose strings must say what is accessed and why, in the user's language, without vague text such as "needs access to your photos". Because the app uses `.readWrite` and deletes and favorites, the string must mention that it can delete and favorite, not just view. No app name placeholder (strings are static per locale). A reassurance on privacy is allowed and helpful.

**Final EN** (`InfoPlist.strings`, en):
`NSPhotoLibraryUsageDescription` = "To show your photos and videos one at a time so you can keep, favorite or delete them. Your photos never leave your iPhone."

**Final ES** (`InfoPlist.strings`, es):
`NSPhotoLibraryUsageDescription` = "Para mostrarte tus fotos y videos uno por uno y que puedas conservarlos, marcarlos como favoritos o eliminarlos. Tus fotos nunca salen de tu iPhone."

Other keys:
- `NSPhotoLibraryAddUsageDescription`: **not needed**; the app does not save new items. Omit unless that changes.
- Recommended: set `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` = `YES` so the app shows its own limited-access banner instead of the system re-prompt on each launch (supports the "no forced prompts" goal). Engineer to confirm UX.
- Localize both strings in `InfoPlist.strings` for `en` and `es`, and set `CFBundleLocalizations`.

## 8. Category and copyright

- Primary: **Photo & Video**. Secondary: **Utilities**. Photo & Video matches the function; Utilities is accurate for storage clean-up. Avoid "Productivity" (weaker fit). 
- Copyright line (ASC > App Information): `© {YEAR} {DEVELOPER_NAME}`, year of first release, legal name of the account holder. Do not put the app name or a brand that is not the entity.
- Support URL: `{SUPPORT_URL}` (must be live at submission, see review-risks.md 1.5). Marketing URL optional.

## Placeholders to fill

`{AppName}`, `{DEVELOPER_NAME}`, `{SUPPORT_EMAIL}`, `{SUPPORT_URL}`, `{PRIVACY_POLICY_URL}`, `{YEAR}`, `{TRADER_ADDRESS}`, `{TRADER_PHONE}`, and the trader/not-trader decision.
