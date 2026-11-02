"""Package the signed artifacts, submission guide and optional draft listing assets."""
from pathlib import Path
import json
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
version = re.search(r"versionName\s+'([^']+)'", (ROOT / 'app/build.gradle').read_text()).group(1)
release = ROOT / 'release'
drafts = release / 'play-preparation'
drafts.mkdir(exist_ok=True)
images = list(drafts.rglob('*.png'))
for file in images:
    data = file.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'Invalid PNG'
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    if file.name == 'icon-512.png':
        assert (width, height) == (512, 512) and len(data) <= 1024 * 1024
    elif file.name.startswith('feature-'):
        assert (width, height) == (1024, 500) and color == 2, 'Feature graphic must be RGB, without alpha'
    else:
        assert min(width, height) >= 320 and max(width, height) <= 3840
        assert max(width, height) <= min(width, height) * 2
    assert len(data) < 8 * 1024 * 1024

(drafts / 'README.txt').write_text(f'''Brújula {version} — Google Play preparation

No upload to Play Console or submission has been made.

Upload Brujula-{version}.aab only when you choose to begin testing.
Install Brujula-{version}.apk directly on Android to update an existing release installation.

Read google-play-preparation.md and VERIFICATION.md. The account, verified public support email,
declarations, Android device acceptance, closed testing where required and Google review remain
pending. This preparation is not store approval.

The screenshot PNG files are clean browser-rendered drafts, not native Android captures.
Review or replace them using a real device or emulator before submission.
They contain no personal scores or notes. No signing keys are included.
''', encoding='utf-8')

files = [ROOT / 'docs/google-play-preparation.md', release / 'VERIFICATION.md']
files += list(release.glob(f'Brujula-{version}.*'))
files += [file for file in drafts.rglob('*') if file.is_file()]
destination = release / f'Brujula-{version}-Play-preparation.zip'
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in files:
        relative = file.relative_to(drafts).as_posix() if drafts in file.parents else file.name
        archive.write(file, f'Brujula-{version}/' + relative)
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert not any(name.endswith(('.jks', '.keystore', '.dpapi', '.db', '.sqlite')) for name in archive.namelist())
print(json.dumps({'draft_png_assets': len(images), 'preparation_zip': destination.name, 'bytes': destination.stat().st_size}))
