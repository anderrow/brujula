"""Capture current build checks and reject evidence for changed source or artifacts."""
from pathlib import Path
from hashlib import sha256
import argparse
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {'core', 'calendar-compile', 'calendar', 'web-generated', 'privacy-generated',
            'packaging-tests', 'android-release', 'apk-signature', 'aab-signature',
            'bundle-validation', 'alignment'}


def digest(path):
    return sha256(Path(path).read_bytes()).hexdigest()


def fingerprint(root=ROOT, paths=None):
    if paths is None:
        paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard'],
                                        cwd=root, text=True, encoding='utf-8').splitlines()
    result = sha256()
    for name in sorted(set(paths)):
        if re.fullmatch(r'docs/verification-v[^/]+\.md', name):
            continue  # Generated historical evidence is not a build input.
        path = Path(root) / name
        if not path.is_file():
            raise ValueError('Missing source input: ' + name)
        data = path.read_bytes()
        result.update(name.encode('utf-8') + b'\0' + len(data).to_bytes(8, 'big') + data)
    return result.hexdigest()


def version():
    return re.search(r"versionName\s+'([^']+)'", (ROOT / 'app/build.gradle').read_text()).group(1)


def receipt_path():
    return ROOT / 'output' / f'verification-{version()}.json'


def save(receipt):
    path = receipt_path()
    path.parent.mkdir(exist_ok=True)
    temporary = path.with_suffix('.part')
    temporary.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def valid_command(name, argv):
    command = Path(argv[0]).name.lower() if argv else ''
    args = argv[1:]
    if name == 'core':
        return command in {'node', 'node.exe'} and args == ['--test', 'tests/core.test.cjs']
    if name in {'web-generated', 'privacy-generated'}:
        script = 'tools/build-web-app.cjs' if name == 'web-generated' else 'tools/generate-privacy.cjs'
        return command in {'node', 'node.exe'} and args == [script, '--check']
    if name == 'packaging-tests':
        return command in {'python', 'python.exe'} and args == ['-m', 'unittest', 'discover', '-s', 'tests', '-p', 'verification_test.py']
    if name == 'calendar-compile':
        return command in {'javac', 'javac.exe'} and args == ['-d', '.toolchain/calendar-tests', 'app/src/main/java/app/brujula/life/ReminderSchedule.java', 'tests/ReminderScheduleTest.java']
    if name == 'calendar':
        return command in {'java', 'java.exe'} and args == ['-cp', '.toolchain/calendar-tests', 'ReminderScheduleTest']
    if name == 'android-release':
        return command in {'gradle', 'gradle.bat'} and set(args) == {'--no-daemon', '--console=plain', 'assembleRelease', 'bundleRelease', 'testReleaseUnitTest', 'lintRelease'}
    if name == 'apk-signature':
        return command in {'apksigner', 'apksigner.bat'} and args == ['verify', '--verbose', '--print-certs', f'release/Brujula-{version()}.apk']
    if name == 'aab-signature':
        return command in {'java', 'java.exe'} and args == ['tools/VerifyBundleSignature.java', f'release/Brujula-{version()}.aab', '9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe']
    if name == 'bundle-validation':
        return command in {'java', 'java.exe'} and args == ['-jar', '.toolchain/bundletool-1.18.3.jar', 'validate', f'--bundle=release/Brujula-{version()}.aab']
    if name == 'alignment':
        return command in {'zipalign', 'zipalign.exe'} and args[:4] == ['-c', '-v', '4', f'release/Brujula-{version()}.apk']
    return False


def validate(receipt, root=ROOT):
    if receipt.get('schema') != 1 or receipt.get('status') != 'complete':
        raise ValueError('No complete current release verification receipt. Run tools/build.ps1 without SkipLint.')
    if receipt.get('fingerprint') != fingerprint(root):
        raise ValueError('Source changed after verification; rebuild before packaging.')
    checks = receipt.get('checks', {})
    for name in REQUIRED:
        check = checks.get(name, {})
        if check.get('exit_code') != 0 or not valid_command(name, check.get('argv', [])):
            raise ValueError('Missing or unqualified current check: ' + name)
        log = Path(root) / check['log']
        if not log.is_file() or digest(log) != check.get('log_sha256'):
            raise ValueError('Check output changed or is missing: ' + name)
    if set(receipt.get('artifacts', {})) != {f'release/Brujula-{version()}.apk', f'release/Brujula-{version()}.aab'}:
        raise ValueError('Receipt must bind both current release artifacts.')
    for name, expected in receipt['artifacts'].items():
        if digest(Path(root) / name) != expected:
            raise ValueError('Artifact changed after verification: ' + name)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['begin', 'capture', 'finish'])
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.action == 'begin':
        receipt_path().unlink(missing_ok=True)
        save({'schema': 1, 'status': 'incomplete', 'fingerprint': fingerprint(),
              'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'checks': {}, 'artifacts': {}, 'optional_acceptance': {'browser_ui': 'not attested', 'physical_devices': 'not run', 'ios': 'separate CI evidence'}})
        return
    receipt = json.loads(receipt_path().read_text(encoding='utf-8'))
    if receipt['fingerprint'] != fingerprint():
        raise ValueError('Source changed during verification; begin a new verification run.')
    if args.action == 'capture':
        name, *argv = args.arguments
        if argv and argv[0] == '--':
            argv = argv[1:]
        if not valid_command(name, argv):
            raise ValueError('Command does not match the release-check contract: ' + name)
        # cmd.exe treats forward slashes in a relative batch filename as options.
        # Preserve argv boundaries and use the resolved Windows executable path.
        executable = Path(argv[0])
        if executable.is_file():
            argv[0] = str(executable.resolve())
        log = ROOT / 'output' / f'verification-{version()}-{name}.log'
        with log.open('w', encoding='utf-8') as output:
            result = subprocess.run(argv, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        receipt['checks'][name] = {'argv': argv, 'exit_code': result.returncode,
                                  'log': log.relative_to(ROOT).as_posix(), 'log_sha256': digest(log)}
        save(receipt)
        print(f'{name}: exit {result.returncode}; {log.relative_to(ROOT)}')
        raise SystemExit(result.returncode)
    artifacts = [f'release/Brujula-{version()}.{extension}' for extension in ['apk', 'aab']]
    receipt['artifacts'] = {path: digest(ROOT / path) for path in artifacts}
    receipt['status'] = 'complete'
    validate(receipt)
    save(receipt)
    print('Current source, required checks and APK/AAB digests recorded.')


if __name__ == '__main__':
    main()
