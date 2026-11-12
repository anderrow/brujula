# Brújula 1.3.1 verification

- APK: `Brujula-1.3.1.apk`
- Changes: complete English and Spanish interfaces, including optional reflection prompts, recovery messages, privacy text and browser installation guidance; existing notes, history and backups are preserved
- Update compatibility: versionCode 8; same application ID and signing certificate as previous releases
- Data migration: existing version-1 data is validated and migrated to version 2 without erasing scores, notes, or history; backups remain importable
- Application ID: `app.brujula.life`
- Size: 56,368 bytes
- SHA-256: `6388efd1f53eac5d11bc8e25108eb11cde181d137f3b156281cce5d719bdc11e`
- Android: minimum API 26 (8.0), target/compile API 36
- Release build: successful (`assembleRelease`, `bundleRelease`)
- Android release lint: passed in the current qualified verification invocation; inspect its retained report for advisories.
- Dedicated release signing: APK Signature Scheme v2 verified with `apksigner`
- Signing certificate SHA-256: `9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe`
- ZIP alignment: verified with `zipalign -c -v 4`
- Archive CRC: verified for all entries
- Packaged HTML, CSS, JavaScript: byte-for-byte matches delivered source
- Android permissions: POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED only; no INTERNET or exact-alarm permission
- Required checks: aab-signature, alignment, android-release, apk-signature, bundle-validation, calendar, calendar-compile, core, packaging-tests, privacy-generated, web-generated; every recorded command exited successfully for this source fingerprint
- Source fingerprint: `c35bcf70421e094e1219d3bacf07740a3ae6fa1795fc24f45fcdd474a16cbd8f`
- Source base revision: `e953e797316d2f6644ecf79c941e085cf4c845c5`; the fingerprint identifies the exact working source
- Android release host tests: 34 passing tests, counted from current XML reports
- Browser UI and physical-device acceptance: not attested by this packaging receipt; consult separately dated execution evidence
- App Bundle: structure validated with bundletool 1.18.3; every payload entry verified against the existing release signing certificate
- App Bundle SHA-256: `62ea72324b9d31955f5e33b9267ba77d84f444632e0064e7cf4a9b237c22e2ef`
- No bundled native libraries; Java-only runtime satisfies the native-code aspect of 16 KB page-size compatibility

## Reminder behavior

Reminders start disabled. A local inexact AlarmManager alarm is registered only when enabled and notifications are permitted. Turning reminders off cancels both the alarm and any visible reflection notice. Months shorter than the selected day use their last day. The notification contains no reflection data. System date/timezone changes, reboot, and app updates re-register enabled schedules. Android may delay delivery for power management; a force-stopped app must be reopened.

## Test boundary

This receipt does not attest a physical-device or emulator installation/runtime test. Android scheduling and native-shell tests used Robolectric (including Android 16); any separately executed browser UI checks must be identified by their own current evidence; this package does not infer their success. Actual notification delivery timing, manufacturer battery restrictions, OS permission dialogs, native SQLite lifecycle, keyboard/insets, document pickers, and installation still require device acceptance.

The deliverables are a signed release APK and Android App Bundle. Google Play account setup, public support email, declarations, closed testing where required, pre-launch reports and review remain pending; nothing has been uploaded to Play Console. No test data, build toolchain, signing password, or private keystore is included in it.
