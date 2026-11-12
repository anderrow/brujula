"""Regression checks for stale verification and unsupported pass claims."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verification', Path(__file__).resolve().parents[1] / 'tools/verification.py')
verification = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verification)


class VerificationTests(unittest.TestCase):
    def test_fingerprint_detects_source_changes_and_is_order_independent(self):
        output = Path(__file__).resolve().parents[1] / 'output' / 'verification-tests'
        output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=output) as directory:
            root = Path(directory)
            self.assertTrue(root.resolve().is_relative_to(output.resolve()))
            (root / 'runtime.js').write_text('before', encoding='utf-8')
            (root / 'test.js').write_text('checks', encoding='utf-8')
            before = verification.fingerprint(root, ['runtime.js', 'test.js'])
            self.assertEqual(before, verification.fingerprint(root, ['test.js', 'runtime.js']))
            (root / 'runtime.js').write_text('after', encoding='utf-8')
            self.assertNotEqual(before, verification.fingerprint(root, ['runtime.js', 'test.js']))

    def test_incomplete_receipts_cannot_authorize_packaging(self):
        with self.assertRaisesRegex(ValueError, 'complete current'):
            verification.validate({'schema': 1, 'status': 'incomplete'})

    def test_debug_build_and_skipped_lint_cannot_attest_release(self):
        self.assertFalse(verification.valid_command('android-release', ['gradle.bat', 'testDebugUnitTest', 'assembleDebug']))
        self.assertFalse(verification.valid_command('android-release', ['gradle.bat', '--no-daemon', '--console=plain', 'assembleRelease', 'bundleRelease', 'testReleaseUnitTest']))
        self.assertTrue(verification.valid_command('android-release', ['gradle.bat', '--no-daemon', '--console=plain', 'assembleRelease', 'bundleRelease', 'testReleaseUnitTest', 'lintRelease']))

    def test_receipt_checks_require_the_actual_suite_command(self):
        self.assertFalse(verification.valid_command('core', ['node', '-e', 'console.log("passed")']))
        self.assertTrue(verification.valid_command('core', ['node', '--test', 'tests/core.test.cjs']))
        self.assertFalse(verification.valid_command('unknown', ['node', '--test', 'tests/core.test.cjs']))


if __name__ == '__main__':
    unittest.main()
