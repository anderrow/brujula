"""Install a pinned, workspace-local Android toolchain without global changes."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / '.toolchain'
TOOLS.mkdir(exist_ok=True)

def download(url, filename, sha=None):
    path = TOOLS / filename
    if not path.exists():
        print('Downloading ' + filename, flush=True)
        temporary = path.with_suffix('.part')
        with urllib.request.urlopen(url, timeout=120) as r, temporary.open('wb') as f:
            while True:
                chunk = r.read(1024 * 1024)
                if not chunk:
                    break
                f.write(chunk)
        temporary.replace(path)
    if sha and hashlib.sha256(path.read_bytes()).hexdigest() != sha:
        raise RuntimeError('Checksum mismatch: ' + filename)
    return path

def android():
    archive = download('https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip', 'android-cli.zip', '98b565cb657b012dae6794cefc0f66ae1efb4690c699b78a614b4a6a3505b003')
    target = TOOLS / 'android-sdk' / 'cmdline-tools' / 'latest'
    if not (target / 'bin' / 'sdkmanager.bat').exists():
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                name = info.filename.removeprefix('cmdline-tools/')
                if name and not info.is_dir():
                    dest = target / name
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(z.read(info))
    print('Android CLI ready', flush=True)

def gradle():
    url = 'https://downloads.gradle.org/distributions/gradle-8.11.1-bin.zip'
    sha = urllib.request.urlopen(url + '.sha256', timeout=60).read().decode().strip()
    archive = download(url, 'gradle.zip', sha)
    if not (TOOLS / 'gradle-8.11.1' / 'bin' / 'gradle.bat').exists():
        with zipfile.ZipFile(archive) as z:
            z.extractall(TOOLS)
    print('Gradle ready', flush=True)

def java():
    req = urllib.request.Request('https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse', headers={'User-Agent': 'BrujulaBuild/1.2'})
    item = json.load(urllib.request.urlopen(req, timeout=60))[0]
    pkg = item['binary']['package']
    archive = download(pkg['link'], 'jdk21.zip', pkg['checksum'])
    with zipfile.ZipFile(archive) as z:
        folder = z.namelist()[0].split('/')[0]
        if not (TOOLS / folder / 'bin' / 'java.exe').exists():
            z.extractall(TOOLS)
    (TOOLS / 'java-home.txt').write_text(str(TOOLS / folder), encoding='utf-8')
    print('JDK 21 ready (Java 17 application bytecode)', flush=True)

def bundletool():
    download('https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar', 'bundletool-1.18.3.jar', 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29')
    print('Bundletool ready', flush=True)

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    list(pool.map(lambda fn: fn(), [android, gradle, java, bundletool]))
