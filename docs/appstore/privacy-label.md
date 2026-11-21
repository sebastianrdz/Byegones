> **DRAFT — attorney review required before use.** Not legal advice. Based on the app specification (no code exists yet); re-verify against the shipped build before submitting.

# App Store Connect: App Privacy answers

## Answers to enter

| ASC question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |
| Resulting label shown on the App Store | **Data Not Collected** |
| Tracking (ATT) | None. Do not add `NSUserTrackingUsageDescription`. |
| Privacy Policy URL | `{PRIVACY_POLICY_URL}` (hosts the content of `docs/legal/privacy-policy.en.md`; add the ES version as localized) |
| User Privacy Choices URL | Leave blank (optional) |

Apple's definition: "collect" means transmitting data off the device in a way that lets you and/or your third-party partners access it for longer than needed to service the request in real time. Data processed only on the device and not sent off it is not "collected." The app makes no network calls and has no SDKs, so nothing is transmitted.

## Per-category justification (ASC lists these; all answer "not collected")

| Category | Collected? | Justification |
|---|---|---|
| Contact Info (name, email, phone, address) | No | No accounts or forms. Support email is handled outside the app. |
| Health & Fitness | No | Not accessed. |
| Financial Info | No | No IAP, no payments. |
| Location | No | No Core Location. Photo location metadata is not read or sent. |
| Sensitive Info | No | Not accessed. |
| Contacts | No | Not accessed. |
| User Content: Photos or Videos | No | Read through PhotoKit and shown on device only. Never transmitted. iCloud download of originals is done by the Photos system, not by the app to the developer. |
| User Content: other (emails, gameplay, customer support, etc.) | No | None. |
| Browsing History | No | No web views or browsing. |
| Search History | No | No search. |
| Identifiers (User ID, Device ID) | No | No IDFA, no IDFV use, no account IDs. Photos `localIdentifier`s are stored on device only and are never sent. |
| Purchases | No | No IAP. |
| Usage Data (product interaction, advertising data) | No | No analytics, no ads. |
| Diagnostics (crash, performance) | No | No crash SDK. Apple-provided crash reports that users opt in to share with developers via iOS settings are Apple's collection, not declared by the app. |
| Other Data | No | None. |

## Conditions that would change the answer (re-do the questionnaire if any occurs)

| Change | Likely new declaration |
|---|---|
| Any analytics or crash SDK (Firebase, Sentry, TelemetryDeck, etc.) | Usage Data and/or Diagnostics, linked or not linked, purpose Analytics. SDK's own privacy manifest also required. |
| Any ad SDK | Identifiers, Usage Data, Advertising; Tracking likely; ATT prompt required. |
| Any server upload or cloud sync of photos, thumbnails, or the identifier list | User Content (Photos/Videos or Other), Identifiers; update policy. |
| Accounts or sign-in | Contact Info, Identifiers. |
| In-app purchase or subscription | Purchases (if stored/tracked outside Apple), possibly Identifiers. |
| Feedback form or email composer that sends data to a backend | Contact Info, User Content (Customer Support). |
| MetricKit uploads to own server | Diagnostics. |
| Any network call at all (even to the developer's own server) | Re-assess; privacy policy and manifest must change too. |
| Reading location metadata and transmitting it | Location. |

## Consistency checklist (must stay true at every release)

- Privacy policy, this label, and `PrivacyInfo.xcprivacy` all say: no tracking, no collected data.
- `PrivacyInfo.xcprivacy` `NSPrivacyCollectedDataTypes` is an empty array.
- No linked frameworks other than Apple system frameworks.
