# Current source update status — November 12, 2026

Current source is iPhone 1.2.0 (build 8). This checklist retains earlier recorded archive/upload observations as history; they do not establish current account state, acceptance or availability. Recheck App Store Connect before acting on any account/create/upload step. This source update does not claim a new upload.

# App Store preparation — Brújula for iPhone 1.1.0 (5)

Prepared on November 4, 2026. On November 5, 2026 the App Store Connect record **Brújula: Wheel of Life** (`6831086667`) was created. Builds 1 and 2 were rejected with ITMS-90129 because the icon name was already used by another app. Build 4 is in internal TestFlight. The icon name is **Brújula: Wheel of Life** in English and **Brújula: Rueda de la vida** in Spanish. External testing and App Review have not started. Recheck the linked Apple pages before uploading.

For this update, validate the new archive and current account state before choosing an internal TestFlight build. External testers and the public App Store come after a device pass on that internal build.

The historical iPhone version line started at **1.0.0 (build 1)**. Current source versions are iPhone **1.2.0 (8)** and Android **1.3.0**. English and Spanish follow the iPhone language. Add a later language in the string catalogs and in the Xcode known regions; `ios/Tests/localizations.cjs` fails until every string has that language.

## Current source settings (November 12, 2026)

- Bundle ID: `app.brujula.life.ios`. Icon name (`CFBundleDisplayName`): Brújula: Wheel of Life (English) and Brújula: Rueda de la vida (Spanish). Short bundle name (`CFBundleName`): BrujulaLife. Category: Lifestyle (`public.app-category.lifestyle`). iPhone only (`TARGETED_DEVICE_FAMILY = 1`). Portrait only.
- Version: `MARKETING_VERSION` 1.2.0. Build: `CURRENT_PROJECT_VERSION` 8. Version 1.0.0 used builds 1 through 4: 1 and 2 were rejected, 3 was cancelled, and 4 is the internal TestFlight build. Apple keeps those build numbers.
- Minimum iOS: 16.0. That meets Apple’s current minimum of iOS 13 (since September 9, 2026) and the April 2027 minimum of iOS 15.
- `ITSAppUsesNonExemptEncryption` is `false` in Debug and Release. The app does not call CryptoKit, CommonCrypto, or its own network stack. Local files use Apple’s complete file protection, which is operating-system encryption. Standard exempt encryption is why the flag is false. Leaving it false lets TestFlight skip the Missing Compliance stop on every upload. If a later change adds non-exempt cryptography, remove this assumption and follow Apple’s export questionnaire.
- `PrivacyInfo.xcprivacy` is in the app bundle. Tracking is off and collected-data types are empty. App-specific UserDefaults language preferences are declared under NSPrivacyAccessedAPICategoryUserDefaults with reason CA92.1. Inspect the current archive privacy report before submission.
- The 1024×1024 App Store icon is an sRGB PNG with no alpha channel. The artwork is a full square; iOS applies the icon mask.
- No third-party SDKs, entitlements, push, iCloud, HealthKit, or advertising frameworks are linked. Charts, SwiftUI, UIKit, Foundation, and UserNotifications are system frameworks. The Release binary also weak-links `libswiftCoreLocation`; the app does not import CoreLocation or request location, and it has no location purpose string. Do not add a purpose string for an API the app does not use.
- `ALWAYS_SEARCH_USER_PATHS` is `NO`, which removes Xcode 27’s traditional-headermap warning.
- The Apple Developer team is not stored in the project. Select it locally under Signing & Capabilities. Automatic signing stays on. A free Personal Team cannot upload to TestFlight.

## Upload SDK and historical observations

Since April 28, 2026, App Store Connect accepts uploads built with Xcode 26 or later and the iOS 26 SDK or later. Starting April 2027, uploads must use Xcode 27 or later and the iOS 27 SDK or later.

Checked on this Mac on November 4, 2026:

- Xcode 27.2 (build `27B52`), SDK `iphoneos27.2`.
- Unsigned Debug simulator build and unsigned Release device build both succeeded.
- The Release `Info.plist` contains `ITSAppUsesNonExemptEncryption = false`, version `1.0.0`, build `1`, bundle `app.brujula.life.ios`, and minimum OS `16.0`.
- The bundled privacy manifest matches the source file.
- The Release executable’s undefined symbols do not include the C entry points Apple lists for required-reason APIs (`stat`, `getattrlist`, `statfs`, `sysctl`, `mach_absolute_time`, UserDefaults). That historical binary inspection predates the current UserDefaults language preference and does not qualify the current source. Inspect the new archive privacy report for its declared preference reason and any additional covered API use.
- Model, backup, and reminder date checks passed. Notification delivery on a physical iPhone has not been tested.
- On November 5, 2026 a Release archive of 1.0.0 (1) was signed with Apple Distribution for Prodfact BV and exported to an IPA. Upload is waiting on an App Store Connect app record. The current API key can upload a build and cannot create that record.

Checked on the iPhone 17 simulator on November 5, 2026, in English:

- Portrait: the wheel, empty history, notes for all eight areas, Settings, and the reminder sheet all open. The reminder switch starts off.
- Landscape left and landscape right put the floating tab bar across the wheel, so the first TestFlight build stays portrait.

## Internal TestFlight

1. Use the existing Prodfact Apple Developer Program membership. Do not create a second account for Brújula. In App Store Connect → Business, the Account Holder accepts the current agreements. Complete tax and banking if that account still lists them before a free app with no in-app purchases can be submitted. Select the Prodfact team in Xcode when archiving. The team ID stays on this Mac and is not stored in the repository.
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

## App Store listing, after a verified current TestFlight build

Add English (U.S.) and Spanish localizations in App Store Connect. The iPhone interface defaults to the phone language and includes system/English/Spanish selection in Settings. Primary language can stay English (U.S.).

| Field | Draft |
| --- | --- |
| Name | Brújula: Wheel of Life |
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
> English and Spanish follow the language of your iPhone. Brújula is a personal reflection tool, not a medical device. It does not diagnose, treat, cure, or prevent any condition, and it does not replace professional advice.

Spanish name: **Brújula: Rueda de la vida**.

Spanish subtitle: **Rueda de la vida privada**.

Spanish promotional text:

> Una rueda privada para ocho áreas de tu vida. Puntuaciones, notas e historial se quedan en el iPhone. Recordatorios locales opcionales. Sin cuenta.

Spanish keywords: `reflexión,diario,rueda de la vida,notas,evaluación,sin conexión,privado,recordatorio,estilo de vida`

Spanish description:

> Encuentra un pequeño espacio para ti con Brújula. Reflexiona sobre ocho áreas de tu vida: salud, trabajo, finanzas, familia, amistades, pareja, ocio y crecimiento.
>
> Empieza con una rueda vacía y valora cada área de 0 a 10. Escribe una nota, guarda una evaluación y compara tus reflexiones con el tiempo. El historial conserva las puntuaciones y notas de cada momento guardado.
>
> Elige un recordatorio diario, semanal o mensual a una hora local, o desactívalo cuando quieras. Se aplican los ajustes de notificaciones y Concentración de iOS. Del 29 al 31, si ese día no existe, se usa el último día del mes.
>
> Tus reflexiones se quedan en el iPhone. Sin inicio de sesión, anuncios, analítica ni conexión a Internet. Exporta y restaura copias locales JSON cuando tú decidas, también una copia hecha en Android. Exporta antes de borrar la app o cambiar de teléfono. Las copias incluyen tus notas y Brújula no las cifra.
>
> El iPhone usa el idioma del teléfono: español e inglés. Brújula es una herramienta de reflexión personal, no un producto sanitario. No diagnostica, trata, cura ni previene enfermedades y no sustituye el consejo profesional.

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
