# Brújula for iPhone

To start using Brújula on an iPhone, open the web app in Safari and choose **Share → Add to Home Screen**. It includes the wheel, notes, history, and backups. Scheduled reminders are available in the native app described below. [Open Brújula on iPhone](https://anderrow.github.io/brujula/web-app/)

The iPhone port is a native SwiftUI app for iOS 16 or later. It has an interactive life wheel, notes, check-in history, trends, comparisons, optional reminders, and local JSON backups. It starts empty and does not require an account or Internet connection. The iPhone interface is in English.

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

From the repository root on macOS:

```sh
node ios/Tests/android-fixture.cjs /tmp/brujula-android-backup.json
swiftc ios/Brujula/ReflectionModel.swift ios/Brujula/ReminderSchedule.swift ios/Tests/main.swift -o /tmp/brujula-ios-checks
/tmp/brujula-ios-checks /tmp/brujula-android-backup.json
xcodebuild -project ios/Brujula.xcodeproj -scheme Brujula -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
