# Brújula 1.1.0 verification

- APK: `Brujula-1.1.0.apk`
- Changes: empty new installations, optional daily/weekly/monthly reflection reminders, confirmed reset of existing data
- Update compatibility: versionCode 3; same application ID and signing certificate as previous releases
- Data migration: existing version-1 data is validated and migrated to version 2 without erasing scores, notes, or history; backups remain importable
- Application ID: `app.brujula.life`
- Size: 39,936 bytes
- SHA-256: `d0d10e2bbfcf9a86782eb54daa5847d21604c0f3f8f69e173c7703c730b8cfb0`
- Android: minimum API 26 (8.0), target/compile API 35
- Release build: successful (`assembleRelease`)
- Android lint: no issues (`lintRelease`)
- Dedicated release signing: APK Signature Scheme v2 verified with `apksigner`
- Signing certificate SHA-256: `9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe`
- ZIP alignment: verified with `zipalign -c -v 4`
- Archive CRC: verified for all entries
- Packaged HTML, CSS, JavaScript: byte-for-byte matches delivered source
- Android permissions: POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED only; no INTERNET or exact-alarm permission
- Data-model tests: six passing Node tests (clean start, snapshot isolation, restore validation, migration, partial averages, geometry)
- Calendar calculation: 15 passing checks against the production Java recurrence calculator (daily, weekly, monthly, leap years, short months, DST, midnight, invalid input)
- Android host tests: seven passing Robolectric API 33 tests (default-off, one pending alarm, replacement, delivery, cancellation, system-change receivers, permission denial, invalid calendar input)
- Headless UI checks: 26 passed, including first use, score entry, save/reload, three reminder frequencies, disabling, permission-denied feedback, English localization, reset confirmation, old-data migration, invalid backups and responsive layouts
- Visual inspection: clean wheel, weekly reminder and monthly reminder screenshots inspected

## Reminder behavior

Reminders start disabled. A local inexact AlarmManager alarm is registered only when enabled and notifications are permitted. Turning reminders off cancels both the alarm and any visible reflection notice. Months shorter than the selected day use their last day. The notification contains no reflection data. System date/timezone changes, reboot, and app updates re-register enabled schedules. Android may delay delivery for power management; a force-stopped app must be reopened.

## Test boundary

No Android device was attached to ADB. No physical-device or emulator installation/runtime test was performed. Android scheduling tests used Robolectric; UI tests used headless Chrome with browser storage and a simulated native bridge. Actual notification delivery timing, manufacturer battery restrictions, OS permission dialogs, native SQLite lifecycle, keyboard/insets, document pickers, and installation still require device acceptance.

The deliverable is a signed release APK. No test data, build toolchain, signing password, or private keystore is included in it.
