# Brújula for iPhone

To start using Brújula on an iPhone, open the web app in Safari and choose **Share → Add to Home Screen**. It includes the wheel, notes, history, and backups. Scheduled reminders are available in the native app described below. [Open Brújula on iPhone](https://anderrow.github.io/brujula/web-app/)

The iPhone port is a native SwiftUI app for iOS 16 or later. It has an interactive life wheel, notes, check-in history, trends, comparisons, optional reminders, and local JSON backups. It starts empty and does not require an account or Internet connection. English and Spanish are available in **Settings → Language**. Choose the phone's language or select a language explicitly; the interface changes immediately and remembers the selection after relaunch.

Language preferences are specific to this installation and are separate from reflection backups. Changing the interface language preserves notes, scores, and saved check-in titles. Future reminder text follows the selected language. System permission dialogs follow the iPhone's settings. Translations live in the Xcode string catalogs; source keys, comments, and documentation remain in English.

The native interface follows the Android app's cream and green palette, serif headings, summary cards, area colors and icons, and three-tab navigation. Tap a wheel label or sector to open an area, or drag its point to change its score directly. Hollow points on an empty wheel are touch targets; they do not assign sample scores. VoiceOver users can adjust each point with swipe-up/down actions. Scores and notes save automatically, and dragging commits when the gesture ends.

Open the labeled **Reminders** bell in the header or **Settings → Reflection reminder**. Both open the same daily, weekly and monthly scheduling controls. The header announces whether reminders are off, on, or blocked by notification permissions.

## Run on an iPhone

1. On a Mac, clone this repository and open `ios/Brujula.xcodeproj` in Xcode 16 or later.
2. In the Brujula target, open **Signing & Capabilities**. Enable automatic signing and select your Apple development team. If the bundle identifier is unavailable for your team, change it to a unique identifier. An installed app's local data stays associated with its original bundle identifier and signing team.
3. Connect and select your iPhone. Follow Xcode's prompts to trust the device and enable Developer Mode if needed, then click **Run**. For a simulator, select any available iPhone simulator instead.

A build made without signing cannot be installed on a physical iPhone. TestFlight and App Store distribution still need a paid Apple Developer team, a signed archive, and the steps in [App Store preparation](../docs/app-store-preparation.md). Nothing has been uploaded to App Store Connect. An upload needs Xcode 26 or later; the current SDK minimum is recorded in that checklist. The project sets `ITSAppUsesNonExemptEncryption` to false so a TestFlight build is not held for the export-compliance questionnaire.

## Transfer reflections from Android

Export a JSON backup from Android settings. Transfer it privately, then choose **Settings → Restore backup** in the iPhone app. Review the confirmation before replacing the current reflections. This transfers draft scores, notes and check-ins. Configure reminders again on the iPhone; schedules and notification permissions are device-specific. Exported backups contain the reflection text and are not encrypted by Brújula.

## Reminders and privacy

Daily, weekly and monthly reminders are scheduled by iOS. If a selected date is missing from a month, the reminder uses that month's last day. Dates from the 29th through the 31st use a rolling schedule of up to 48 local notifications, replenished when the app opens. iOS notification permissions, Focus and delivery settings apply.

Reflections and reminder settings live in protected app files excluded from automatic backups. The app includes its privacy policy in Settings. It does not use tracking, ads, analytics, third-party SDKs or a server. Deleting local data leaves any separately exported backup files in their chosen locations.

## Build and verify

The iPhone workflow compiles the app for the simulator and for iPhone hardware without signing, checks data and reminder logic using an Android-generated backup, and launches the app on an iPhone simulator. Real-device acceptance still includes notification delivery, Files integration and signing with the selected Apple team.

The simulator UI check also edits scores and notes, drags a wheel point, relaunches to verify persistence, grants notification permission, saves a reminder, and cancels it through Settings. It switches to Spanish, checks the translated interface and unchanged note, relaunches to check the saved language, and switches back to English. Screenshots and the test result bundle are uploaded with the workflow. These checks verify the controls and stored schedule; physical-device notification delivery still needs acceptance on the phone.

From the repository root on macOS:

```sh
node ios/Tests/localizations.cjs
node ios/Tests/android-fixture.cjs /tmp/brujula-android-backup.json
swiftc ios/Brujula/Localization.swift ios/Brujula/ReflectionModel.swift ios/Brujula/ReminderSchedule.swift ios/Tests/main.swift -o /tmp/brujula-ios-checks
/tmp/brujula-ios-checks /tmp/brujula-android-backup.json
xcodebuild -project ios/Brujula.xcodeproj -scheme Brujula -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
