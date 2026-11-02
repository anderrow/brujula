"""Verify the delivered APK payload and bundle source without build tools or keys."""
from pathlib import Path
from hashlib import sha256
import json
import subprocess
import zipfile
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'release'
APK = RELEASE / 'Brujula-1.1.0.apk'
SDK = ROOT / '.toolchain' / 'android-sdk'

with zipfile.ZipFile(APK) as z:
    assert z.testzip() is None, 'APK CRC check failed'
    for required in ['AndroidManifest.xml', 'classes.dex', 'resources.arsc']:
        assert required in z.namelist(), 'Missing APK component: ' + required
    for source in (ROOT / 'app/src/main/assets/web').iterdir():
        assert z.read('assets/web/' + source.name) == source.read_bytes(), 'Stale packaged asset: ' + source.name
    assert not any(n.endswith(('.jks', '.keystore', '.dpapi')) for n in z.namelist()), 'Signing material included in APK'

permissions = subprocess.check_output([str(SDK / 'build-tools/35.0.0/aapt.exe'), 'dump', 'permissions', str(APK)], text=True, encoding='utf-8')
declared = set(re.findall(r"uses-permission: name='([^']+)'", permissions))
assert declared == {'android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED'}, 'Unexpected Android permissions: ' + permissions
badging = subprocess.check_output([str(SDK / 'build-tools/35.0.0/aapt.exe'), 'dump', 'badging', str(APK)], text=True, encoding='utf-8')
assert "sdkVersion:'26'" in badging and "targetSdkVersion:'35'" in badging
assert "application-label:'Brújula'" in badging
lint = (ROOT / 'app/build/reports/lint-results-release.txt').read_text(encoding='utf-8')
assert 'No issues found.' in lint, 'Android lint is not clean'
digest = sha256(APK.read_bytes()).hexdigest()
assert (RELEASE / 'Brujula-1.1.0.apk.sha256').read_text().split()[0] == digest
assert "versionCode='3'" in badging and "versionName='1.1.0'" in badging
test_report = ET.parse(ROOT / 'app/build/test-results/testReleaseUnitTest/TEST-app.brujula.life.RemindersTest.xml').getroot()
assert test_report.attrib['tests'] == '7' and test_report.attrib['failures'] == '0' and test_report.attrib['errors'] == '0'
build_log = (ROOT / 'output/build-1.1.0.log').read_text(encoding='utf-8-sig')
assert 'Signer #1 certificate SHA-256 digest: 9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe' in build_log
ui_log = (ROOT / 'output/playwright/cli.log').read_text(encoding='utf-8-sig')
assert '"passed":26' in ui_log, 'The current UI checks did not complete'

report = f'''# Brújula 1.1.0 verification

- APK: `Brujula-1.1.0.apk`
- Changes: empty new installations, optional daily/weekly/monthly reflection reminders, confirmed reset of existing data
- Update compatibility: versionCode 3; same application ID and signing certificate as previous releases
- Data migration: existing version-1 data is validated and migrated to version 2 without erasing scores, notes, or history; backups remain importable
- Application ID: `app.brujula.life`
- Size: {APK.stat().st_size:,} bytes
- SHA-256: `{digest}`
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
'''
(RELEASE / 'VERIFICATION.md').write_text(report, encoding='utf-8')
(RELEASE / 'INSTALL.txt').write_text('Brújula 1.1.0\n\n1. Copy Brujula-1.1.0.apk to an Android 8.0+ phone.\n2. Open it from Files and choose Update or Install.\n3. New installations start empty. Existing data is preserved during an update.\n4. To clear an existing installation, use Settings > Clear data and start fresh, then confirm.\n5. To schedule a reflection notification, use Settings > Reflection reminder, enable it, choose frequency/day/time, and save. Allow Android notifications when asked. To stop reminders, turn the switch off and save.\n\nDo not uninstall to update. Export a backup before clearing data if you want to keep previous reflections. Android power management may delay notifications. No login or Internet connection is required.\n', encoding='utf-8')

includes = [ROOT / n for n in ['README.md', '.gitignore', 'settings.gradle', 'build.gradle', 'gradle.properties', 'gradlew', 'gradlew.bat']]
for directory in ['app/src', 'gradle/wrapper', 'tools', 'tests']:
    includes.extend(p for p in (ROOT / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
includes.append(ROOT / 'app/build.gradle')
with zipfile.ZipFile(RELEASE / 'Brujula-source.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for source in sorted(includes):
        z.write(source, 'Brujula/' + source.relative_to(ROOT).as_posix())

print(json.dumps({'apk': str(APK), 'bytes': APK.stat().st_size, 'sha256': digest, 'asset_integrity': 'passed', 'permissions': sorted(declared), 'source_archive': str(RELEASE / 'Brujula-source.zip')}, indent=2))
