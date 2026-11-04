# App Store preparation — Brújula for iPhone 1.0.0 (1)

Prepared on November 4, 2026. **No build has been uploaded to App Store Connect, sent to TestFlight, or submitted for App Review.** This checklist is preparation, not a guarantee of acceptance. Recheck the linked Apple pages before uploading.

The first distribution step is internal TestFlight. External testers and the public App Store come after a device pass on that internal build.

The iPhone version line starts at **1.0.0 (build 1)**. Android 1.2.0 is a separate release. The iPhone interface is English.

## Project settings already in the repository

- Bundle ID: `app.brujula.life.ios`. Display name: Brújula. Category: Lifestyle (`public.app-category.lifestyle`). iPhone only (`TARGETED_DEVICE_FAMILY = 1`).
- Version: `MARKETING_VERSION` 1.0.0. Build: `CURRENT_PROJECT_VERSION` 1. After App Store Connect accepts an upload, increment the build number before the next upload.
- Minimum iOS: 16.0. That meets Apple’s current minimum of iOS 13 (since September 9, 2026) and the April 2027 minimum of iOS 15.
- `ITSAppUsesNonExemptEncryption` is `false` in Debug and Release. The app does not call CryptoKit, CommonCrypto, or its own network stack. Local files use Apple’s complete file protection, which is operating-system encryption. Standard exempt encryption is why the flag is false. Leaving it false lets TestFlight skip the Missing Compliance stop on every upload. If a later change adds non-exempt cryptography, remove this assumption and follow Apple’s export questionnaire.
- `PrivacyInfo.xcprivacy` is in the app bundle. Tracking is off, collected-data types are empty, and required-reason API entries are empty.
- The 1024×1024 App Store icon is an sRGB PNG with no alpha channel. The artwork is a full square; iOS applies the icon mask.
- No third-party SDKs, entitlements, push, iCloud, HealthKit, or advertising frameworks are linked. Charts, SwiftUI, UIKit, Foundation, and UserNotifications are system frameworks. The Release binary also weak-links `libswiftCoreLocation`; the app does not import CoreLocation or request location, and it has no location purpose string. Do not add a purpose string for an API the app does not use.
- `ALWAYS_SEARCH_USER_PATHS` is `NO`, which removes Xcode 27’s traditional-headermap warning.
- The Apple Developer team is not stored in the project. Select it locally under Signing & Capabilities. Automatic signing stays on. A free Personal Team cannot upload to TestFlight.

## Upload SDK

Since April 28, 2026, App Store Connect accepts uploads built with Xcode 26 or later and the iOS 26 SDK or later. Starting April 2027, uploads must use Xcode 27 or later and the iOS 27 SDK or later.

Checked on this Mac on November 4, 2026:

- Xcode 27.2 (build `27B52`), SDK `iphoneos27.2`.
- Unsigned Debug simulator build and unsigned Release device build both succeeded.
- The Release `Info.plist` contains `ITSAppUsesNonExemptEncryption = false`, version `1.0.0`, build `1`, bundle `app.brujula.life.ios`, and minimum OS `16.0`.
- The bundled privacy manifest matches the source file.
- The Release executable’s undefined symbols do not include the C entry points Apple lists for required-reason APIs (`stat`, `getattrlist`, `statfs`, `sysctl`, `mach_absolute_time`, UserDefaults). The app source does not call those APIs. Before the first upload, open the Organizer archive’s privacy report and confirm it still shows no missing reasons.
- Model, backup, and reminder date checks passed. Notification delivery on a physical iPhone has not been tested. This was not a signed archive.

## Internal TestFlight

1. Use a paid Apple Developer Program membership. In App Store Connect → Business, the Account Holder accepts the current agreements. Complete tax and banking if that account still lists them before a free app with no in-app purchases can be submitted.
2. Register the App ID `app.brujula.life.ios` with no extra capabilities. In Xcode, choose the team and keep automatic signing. Keep this bundle ID for as long as installed copies should retain their local data.
3. Create the App Store Connect record: name **Brújula**, primary language English (U.S.), bundle ID above, SKU `brujula-ios` (any unique SKU is fine).
4. Select Any iOS Device (arm64), then Product → Archive, using Release. Distribute to App Store Connect and upload. Wait until the build appears under TestFlight and processing finishes. Check email as well as the TestFlight tab; a processing failure can leave no build.
5. Confirm the build is not stuck on Missing Compliance. The encryption flag above is what answers that question.
6. Add an internal group and invite people who already have a role on the App Store Connect team. Internal testing does not require Beta App Review. Install through the TestFlight app.
7. On a physical iPhone, with the network off as well as on, check:
   - a new install opens an empty wheel, with unanswered areas distinct from a chosen zero;
   - rating all eight areas, notes, and saving a check-in;
   - history, trend, and comparison;
   - reminders off by default, the permission prompt, denial, and a saved daily, weekly, and end-of-month date;
   - notification text contains no scores or notes;
   - export, restore, and Clear data and start fresh;
   - an Android JSON backup restores scores, notes, and check-ins, and does not turn reminders on.
8. Builds expire 90 days after upload.

## External TestFlight

Do this after the internal device pass. The first external build of a version goes through Beta App Review and must follow the App Review Guidelines. TestFlight builds cannot be given in exchange for payment.

Before inviting external testers, enter:

- App Privacy, published: **Data Not Collected**. Reflections stay on the device. The developer does not receive them. A file the person saves with the document picker is not collection by Brújula. There is no tracking and no third-party partner.
- Privacy policy URL: `https://anderrow.github.io/brujula/privacy.html`
- Beta App Description, for example: “Private wheel of life for iPhone. Scores, notes, history, and optional local reminders stay on the device. No account.”
- Feedback email: a real address the Account Holder chooses. The repository does not contain one. GitHub Issues are public and are not a substitute for this field.
- Beta App Review contact name, phone, and email. Leave sign-in empty. There is no account and no demo password.
- Notes: “No login. The first screen is an empty wheel. Settings contains export, restore, clear data, and the privacy policy. Reminders are optional and local. The Health row is a self-assigned life-area score, not a medical feature.”

## App Store listing, after TestFlight

Use English metadata. The Android listing’s Spanish availability sentence describes the Android app.

| Field | Draft |
| --- | --- |
| Name | Brújula |
| Subtitle | Private wheel of life |
| Promotional text | A private wheel for eight areas of life. Scores, notes, and history stay on your iPhone. Optional local reminders. No account. |
| Keywords | `reflection,journal,wheel of life,notes,check-in,offline,private,reminder,lifestyle` |
| Support URL | `https://github.com/anderrow/brujula/issues` |
| Marketing URL | Leave blank until the public website describes the App Store app. The current site tells iPhone visitors to use the Safari web app and offers an Android APK. |
| Privacy Policy URL | `https://anderrow.github.io/brujula/privacy.html` |
| Copyright | `2026 Brújula project`, unless the legal name on the account should appear instead |
| Price | Free. No in-app purchases. |
| Primary category | Lifestyle |
| Age rating | See the questionnaire below. Leave Made for Kids unselected. |

Description:

> Make a little space for yourself with Brújula. Reflect on eight areas of your life: health, work, finances, family, friends, partner, leisure, and growth.
>
> Start with a clean wheel and rate each area from 0 to 10. Write a personal note, save a check-in, and compare your reflections over time. Your history keeps the scores and notes from each saved moment.
>
> Choose an optional daily, weekly, or monthly reminder at a local time, or turn reminders off whenever you like. iOS notification settings and Focus apply. Dates from the 29th through the 31st use that month’s last day when the date does not exist.
>
> Your reflections stay on your iPhone. No sign-in, ads, analytics, or Internet connection are required. Export and restore local JSON backups when you choose, including a backup made on Android. Export before deleting the app or changing phones. Exported files include your notes and are not encrypted by Brújula.
>
> The iPhone app is in English. Brújula is a personal reflection tool, not a medical device. It does not diagnose, treat, cure, or prevent any condition, and it does not replace professional advice.

### Age rating questionnaire

Apple computes the rating from these answers. Recommended answers for the current app:

- In-app controls: no parental controls and no age assurance.
- Capabilities: no in-app browser, no broadly distributed user content, no social feed, no messaging, and no advertising. The support link opens Safari outside the app.
- Mature themes, sexuality or nudity, violence, and chance-based activities: none.
- Medical or Treatment Information: none. The app does not provide diagnoses or treatment guidance.
- Health or Wellness Topics: none. The Health row stores a score the person enters. The app does not provide self-care recommendations, calorie tracking, diet advice, or exercise plans. Choose this descriptor if you decide the wheel itself is wellness content; on the current scale that raises the rating to 9+.

With every descriptor set to none, the current scale describes a 4+ rating. Confirm the value App Store Connect displays after you save the questionnaire.

### Screenshots

Internal TestFlight does not need screenshots. App Review does.

Apple’s screenshot page, checked November 4, 2026, requires at least one screenshot for **iPhone with Dynamic Island (medium display)**. Portrait sizes listed for that class include 1179×2556 and 1206×2622. PNG or JPEG, with no alpha channel. Up to 10. Show the app in use, including an empty wheel and a wheel filled with obvious sample scores. Do not use a person’s real reflections. iPad screenshots are not required while the target stays iPhone-only.

From April 2027, apps built with the iOS 27.1 SDK or later also need iPhone Duo screenshots (outer display 1398×2034, inner display 2007×2853). This project builds with the iOS 27.2 SDK, so reread that rule before an App Store submission on or after that date. Do not add caption text claiming iPhone Duo features the app does not have.

### Review notes

> No login, demo account, or network service. The first launch is an empty wheel. Rate all eight areas, then save a check-in from the main screen. Settings includes export, restore, clear data, and the privacy policy. Reminders are off until enabled and are scheduled locally; the notification does not include scores or notes. Health is one self-rated life area. Brújula does not provide medical advice.

### EU Digital Services Act

Before App Store distribution, the Account Holder declares trader or non-trader status under Business → Compliance. Apple does not decide which one applies. A trader must provide contact details that Apple publishes on EU product pages. TestFlight by itself is not distribution on the App Store. The declaration is still required when the app is submitted, including for accounts that do not sell in the EU.

## Official references

- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Submitting](https://developer.apple.com/app-store/submitting/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Export compliance for beta builds](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds/)
- [Complying with encryption export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifests](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [Required-reason APIs (TN3183)](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Age ratings](https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/)
- [EU Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-compliance-information/)
