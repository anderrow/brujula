# Brújula 1.2.0 verification

- APK: `Brujula-1.2.0.apk`
- Changes: Android 16 / API 36, signed App Bundle, native safe-area handling, offline bilingual privacy policy and Google Play preparation
- Update compatibility: versionCode 5; same application ID and signing certificate as previous releases
- Data migration: existing version-1 data is validated and migrated to version 2 without erasing scores, notes, or history; backups remain importable
- Application ID: `app.brujula.life`
- Size: 43,676 bytes
- SHA-256: `382da3993c2d4d30aaba06414490bab03038b9b18234334f06affa839abf0b4f`
- Android: minimum API 26 (8.0), target/compile API 36
- Release build: successful (`assembleRelease`, `bundleRelease`)
- Android lint: 0 errors; one advisory that a newer Gradle version exists (`AndroidGradlePluginVersion`). The pinned Gradle 8.11.1 is supported by AGP 8.10.1.
- Dedicated release signing: APK Signature Scheme v2 verified with `apksigner`
- Signing certificate SHA-256: `9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe`
- ZIP alignment: verified with `zipalign -c -v 4`
- Archive CRC: verified for all entries
- Packaged HTML, CSS, JavaScript: byte-for-byte matches delivered source
- Android permissions: POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED only; no INTERNET or exact-alarm permission
- Data-model tests: six passing Node tests (clean start, snapshot isolation, restore validation, migration, partial averages, geometry)
- Calendar calculation: 15 passing checks against the production Java recurrence calculator (daily, weekly, monthly, leap years, short months, DST, midnight, invalid input)
- Android host tests: 14 passing Robolectric reminder tests across API 33 and API 36, plus two native-shell API 36 tests. Reminder coverage includes (default-off, one pending alarm, replacement, delivery, cancellation, system-change receivers, permission denial, invalid calendar input)
- Headless UI checks: 26 passed, including first use, score entry, save/reload, three reminder frequencies, disabling, permission-denied feedback, English localization, reset confirmation, old-data migration, invalid backups and responsive layouts
- Privacy UI: six additional checks passed for both offline translations and clean preview state
- App Bundle: structure validated with bundletool 1.18.3; every payload entry verified against the existing release signing certificate
- App Bundle SHA-256: `47aa008b480c8ab04eff02a2075376214357387c1bcf99eae1bfe0de98e2015c`
- No bundled native libraries; Java-only runtime satisfies the native-code aspect of 16 KB page-size compatibility

## Reminder behavior

Reminders start disabled. A local inexact AlarmManager alarm is registered only when enabled and notifications are permitted. Turning reminders off cancels both the alarm and any visible reflection notice. Months shorter than the selected day use their last day. The notification contains no reflection data. System date/timezone changes, reboot, and app updates re-register enabled schedules. Android may delay delivery for power management; a force-stopped app must be reopened.

## Test boundary

No Android device was attached to ADB. No physical-device or emulator installation/runtime test was performed. Android scheduling and native-shell tests used Robolectric (including Android 16); UI tests used headless Chrome with browser storage and a simulated native bridge. Actual notification delivery timing, manufacturer battery restrictions, OS permission dialogs, native SQLite lifecycle, keyboard/insets, document pickers, and installation still require device acceptance.

The deliverables are a signed release APK and Android App Bundle. Google Play account setup, public support email, declarations, closed testing where required, pre-launch reports and review remain pending; nothing has been uploaded to Play Console. No test data, build toolchain, signing password, or private keystore is included in it.
