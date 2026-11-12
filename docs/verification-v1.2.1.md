# Brújula 1.2.1 verification

- APK: `Brujula-1.2.1.apk`
- Changes: reliable portable backups, failed-save recovery, recreation-safe Android document operations, reset ordering and current verification provenance
- Update compatibility: versionCode 6; same application ID and signing certificate as previous releases
- Data migration: existing version-1 data is validated and migrated to version 2 without erasing scores, notes, or history; backups remain importable
- Application ID: `app.brujula.life`
- Size: 54,512 bytes
- SHA-256: `3ecc764de48a351c8d50f00dd22e63fb6f0517f0792e7f86427b8b7344049406`
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
- Source fingerprint: `abbc64d75e75834c38d8be200e54137d080cc95a1807dd02c6bcddd3b1e8dc4b`
- Source base revision: `5f98894b89b0f23bb2e2b418e7d46704af66a4dd`; the fingerprint identifies the exact working source
- Android release host tests: 34 passing tests, counted from current XML reports
- Browser UI and physical-device acceptance: not attested by this packaging receipt; consult separately dated execution evidence
- App Bundle: structure validated with bundletool 1.18.3; every payload entry verified against the existing release signing certificate
- App Bundle SHA-256: `fac61ac175fdcb15de8692a4b330108def59589e56f6396a8fdf2dd22289d7e3`
- No bundled native libraries; Java-only runtime satisfies the native-code aspect of 16 KB page-size compatibility

## Reminder behavior

Reminders start disabled. A local inexact AlarmManager alarm is registered only when enabled and notifications are permitted. Turning reminders off cancels both the alarm and any visible reflection notice. Months shorter than the selected day use their last day. The notification contains no reflection data. System date/timezone changes, reboot, and app updates re-register enabled schedules. Android may delay delivery for power management; a force-stopped app must be reopened.

## Test boundary

This receipt does not attest a physical-device or emulator installation/runtime test. Android scheduling and native-shell tests used Robolectric (including Android 16); any separately executed browser UI checks must be identified by their own current evidence; this package does not infer their success. Actual notification delivery timing, manufacturer battery restrictions, OS permission dialogs, native SQLite lifecycle, keyboard/insets, document pickers, and installation still require device acceptance.

The deliverables are a signed release APK and Android App Bundle. Google Play account setup, public support email, declarations, closed testing where required, pre-launch reports and review remain pending; nothing has been uploaded to Play Console. No test data, build toolchain, signing password, or private keystore is included in it.
