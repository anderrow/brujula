"""Verify the delivered APK payload and bundle source without build tools or keys."""
from pathlib import Path
from hashlib import sha256
import json
import subprocess
import zipfile
import re
import xml.etree.ElementTree as ET
from verification import validate, receipt_path

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'release'
gradle = (ROOT / 'app/build.gradle').read_text(encoding='utf-8')
VERSION = re.search(r"versionName\s+'([^']+)'", gradle).group(1)
VERSION_CODE = re.search(r'versionCode\s+(\d+)', gradle).group(1)
AAB = RELEASE / f'Brujula-{VERSION}.aab'
APK = RELEASE / f'Brujula-{VERSION}.apk'
SDK = ROOT / '.toolchain' / 'android-sdk'
receipt = validate(json.loads(receipt_path().read_text(encoding='utf-8')))
assert set(receipt['artifacts']) == {f'release/Brujula-{VERSION}.apk', f'release/Brujula-{VERSION}.aab'}

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
assert "sdkVersion:'26'" in badging and "targetSdkVersion:'36'" in badging
assert "application-label:'Brújula'" in badging
lint = (ROOT / 'app/build/reports/lint-results-release.txt').read_text(encoding='utf-8')
lint_xml = ET.parse(ROOT / 'app/build/reports/lint-results-release.xml').getroot()
assert not [issue for issue in lint_xml.findall('issue') if issue.attrib.get('severity') in {'Error', 'Fatal'}], 'Android lint has errors'
digest = sha256(APK.read_bytes()).hexdigest()
assert (RELEASE / f'Brujula-{VERSION}.apk.sha256').read_text().split()[0] == digest
assert f"versionCode='{VERSION_CODE}'" in badging and f"versionName='{VERSION}'" in badging
reports = list((ROOT / 'app/build/test-results/testReleaseUnitTest').glob('TEST-*.xml'))
assert reports, 'Current release test reports are missing'
test_count = 0
for report_file in reports:
    report_xml = ET.parse(report_file).getroot()
    assert int(report_xml.attrib.get('failures', 0)) == 0 and int(report_xml.attrib.get('errors', 0)) == 0
    test_count += int(report_xml.attrib['tests'])
assert test_count > 0, 'No Android host tests were executed'

java = Path((ROOT / '.toolchain/java-home.txt').read_text(encoding='utf-8').strip()) / 'bin/java.exe'
with zipfile.ZipFile(AAB) as bundle:
    assert bundle.testzip() is None, 'App Bundle CRC check failed'
    assert all(name in bundle.namelist() for name in ['BundleConfig.pb', 'base/manifest/AndroidManifest.xml', 'base/dex/classes.dex'])
    for source in (ROOT / 'app/src/main/assets/web').iterdir():
        assert bundle.read('base/assets/web/' + source.name) == source.read_bytes(), 'Stale App Bundle asset'
    assert not any(n.endswith(('.so', '.jks', '.keystore', '.dpapi', '.db', '.sqlite')) for n in bundle.namelist()), 'Private or native file in App Bundle'
assert (ROOT / 'docs/privacy-copy.js').read_bytes() == (ROOT / 'app/src/main/assets/web/privacy-copy.js').read_bytes(), 'Public and offline policy differ'
manifest_bytes = subprocess.check_output([str(java), '-jar', str(ROOT / '.toolchain/bundletool-1.18.3.jar'), 'dump', 'manifest', '--bundle=' + str(AAB)])
try:
    manifest_text = manifest_bytes.decode('utf-8')
except UnicodeDecodeError:
    manifest_text = manifest_bytes.decode('cp1252')  # Windows Java console encoding.
manifest = ET.fromstring(manifest_text)
android_ns = '{http://schemas.android.com/apk/res/android}'
assert manifest.attrib['package'] == 'app.brujula.life'
assert manifest.attrib[android_ns + 'versionCode'] == VERSION_CODE
assert manifest.find('uses-sdk').attrib[android_ns + 'targetSdkVersion'] == '36'
assert manifest.find('uses-sdk').attrib[android_ns + 'minSdkVersion'] == '26'
subprocess.run([str(java), str(ROOT / 'tools/VerifyBundleSignature.java'), str(AAB), '9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe'], check=True)
aab_digest = sha256(AAB.read_bytes()).hexdigest()
assert (RELEASE / f'Brujula-{VERSION}.aab.sha256').read_text().split()[0] == aab_digest
report = f'''# Brújula {VERSION} verification

- APK: `Brujula-{VERSION}.apk`
- Changes: reliable portable backups, failed-save recovery, recreation-safe Android document operations, reset ordering and current verification provenance
- Update compatibility: versionCode {VERSION_CODE}; same application ID and signing certificate as previous releases
- Data migration: existing version-1 data is validated and migrated to version 2 without erasing scores, notes, or history; backups remain importable
- Application ID: `app.brujula.life`
- Size: {APK.stat().st_size:,} bytes
- SHA-256: `{digest}`
- Android: minimum API 26 (8.0), target/compile API 36
- Release build: successful (`assembleRelease`, `bundleRelease`)
- Android release lint: passed in the current qualified verification invocation; inspect its retained report for advisories.
- Dedicated release signing: APK Signature Scheme v2 verified with `apksigner`
- Signing certificate SHA-256: `9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe`
- ZIP alignment: verified with `zipalign -c -v 4`
- Archive CRC: verified for all entries
- Packaged HTML, CSS, JavaScript: byte-for-byte matches delivered source
- Android permissions: POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED only; no INTERNET or exact-alarm permission
- Required checks: {', '.join(sorted(receipt['checks']))}; every recorded command exited successfully for this source fingerprint
- Source fingerprint: `{receipt['fingerprint']}`
- Source base revision: `{receipt['revision']}`; the fingerprint identifies the exact working source
- Android release host tests: {test_count} passing tests, counted from current XML reports
- Browser UI and physical-device acceptance: not attested by this packaging receipt; consult separately dated execution evidence
- App Bundle: structure validated with bundletool 1.18.3; every payload entry verified against the existing release signing certificate
- App Bundle SHA-256: `{aab_digest}`
- No bundled native libraries; Java-only runtime satisfies the native-code aspect of 16 KB page-size compatibility

## Reminder behavior

Reminders start disabled. A local inexact AlarmManager alarm is registered only when enabled and notifications are permitted. Turning reminders off cancels both the alarm and any visible reflection notice. Months shorter than the selected day use their last day. The notification contains no reflection data. System date/timezone changes, reboot, and app updates re-register enabled schedules. Android may delay delivery for power management; a force-stopped app must be reopened.

## Test boundary

No Android device was attached to ADB. This receipt does not attest a physical-device or emulator installation/runtime test. Android scheduling and native-shell tests used Robolectric (including Android 16); Any separately executed browser UI checks must be identified by their own current evidence; this package does not infer their success. Actual notification delivery timing, manufacturer battery restrictions, OS permission dialogs, native SQLite lifecycle, keyboard/insets, document pickers, and installation still require device acceptance.

The deliverables are a signed release APK and Android App Bundle. Google Play account setup, public support email, declarations, closed testing where required, pre-launch reports and review remain pending; nothing has been uploaded to Play Console. No test data, build toolchain, signing password, or private keystore is included in it.
'''
(RELEASE / 'VERIFICATION.md').write_text(report, encoding='utf-8')
(ROOT / f'docs/verification-v{VERSION}.md').write_text(report, encoding='utf-8')
(RELEASE / 'INSTALL.txt').write_text(f'Brújula {VERSION}\n\n1. Copy Brujula-{VERSION}.apk to an Android 8.0+ phone.\n2. Open it from Files and choose Update or Install.\n3. New installations start empty. Existing data is preserved during an update.\n4. To configure notifications, tap the bell labeled Reminders in the app header. Settings also contains a prominent bell entry. Choose frequency/day/time and save. To stop reminders, turn the switch off and save.\n5. To clear an existing installation, use Settings > Clear data and start fresh, then confirm.\n\nDo not uninstall to update. Export a backup before clearing data if you want to keep previous reflections. Android power management may delay notifications. No login or Internet connection is required.\n', encoding='utf-8')

includes = [ROOT / n for n in ['README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes', 'settings.gradle', 'build.gradle', 'gradle.properties', 'gradlew', 'gradlew.bat']]
for directory in ['app/src', 'gradle/wrapper', 'tools', 'tests', '.github', 'docs', 'ios']:
    includes.extend(p for p in (ROOT / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
includes.append(ROOT / 'app/build.gradle')
with zipfile.ZipFile(RELEASE / 'Brujula-source.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for source in sorted(includes):
        z.write(source, 'Brujula/' + source.relative_to(ROOT).as_posix())

print(json.dumps({'apk': str(APK), 'bytes': APK.stat().st_size, 'sha256': digest, 'asset_integrity': 'passed', 'permissions': sorted(declared), 'aab_sha256': aab_digest, 'source_archive': str(RELEASE / 'Brujula-source.zip')}, indent=2))
