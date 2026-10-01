"""Regression checks for the version-scoped Salt SSH host-key prompt backport."""

import ast
import importlib.util
from pathlib import Path
import re
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "assets" / "build" / "salt-ssh-host-key-prompt.py"
SPEC = importlib.util.spec_from_file_location("host_key_prompt_patch", SCRIPT)
PATCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH)


class HostKeyPromptPatchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.shell = Path(self.directory.name) / "shell.py"

    def test_versions_before_3008_receive_the_missing_fix(self):
        for version in ((3006, 25), (3007, 9), (3007, 14), (3007, 15), (3007, 16), (3007, 100)):
            with self.subTest(version=version):
                self.shell.write_text("import re\n" + PATCH.OLD_DETECTOR + "\n")
                self.assertTrue(PATCH.patch_host_key_prompt(version, self.shell))
                self.assertIn(PATCH.NEW_DETECTOR, self.shell.read_text())

    def test_patch_recognizes_both_prompt_formats(self):
        self.shell.write_text("import re\n" + PATCH.OLD_DETECTOR + "\n")
        self.assertTrue(PATCH.patch_host_key_prompt((3007, 15), self.shell))
        tree = ast.parse(self.shell.read_text())
        pattern = re.compile(ast.literal_eval(tree.body[1].value.args[0]))
        for prompt in ("(yes/no)", "(yes/no/[fingerprint])"):
            with self.subTest(prompt=prompt):
                self.assertIsNotNone(pattern.match("Are you sure you want to continue connecting " + prompt + "?"))
        self.assertIsNone(pattern.match("Permission denied"))

    def test_versions_at_or_after_3008_are_byte_for_byte_unchanged(self):
        for version in ((3008,), (3008, 0), (3008, 1), (3008, 2), (3008, 3), (3009, 0)):
            with self.subTest(version=version):
                # Even an old detector must not be rewritten outside the requested version range.
                original = b"import re\n" + PATCH.OLD_DETECTOR.encode() + b"\n"
                self.shell.write_bytes(original)
                self.assertFalse(PATCH.patch_host_key_prompt(version, self.shell))
                self.assertEqual(self.shell.read_bytes(), original)

    def test_versions_at_or_after_3008_do_not_require_the_source_file(self):
        self.assertFalse(PATCH.patch_host_key_prompt((3008, 0), self.shell))
        self.assertFalse(self.shell.exists())

    def test_already_fixed_older_versions_are_unchanged(self):
        for version in ((3006, 25), (3007, 14), (3007, 15), (3007, 16)):
            with self.subTest(version=version):
                self.shell.write_text("import re\n" + PATCH.NEW_DETECTOR + "\n")
                original = self.shell.read_bytes()
                self.assertFalse(PATCH.patch_host_key_prompt(version, self.shell))
                self.assertEqual(self.shell.read_bytes(), original)

    def test_reapplying_patch_does_not_modify_the_source(self):
        self.shell.write_text("import re\n" + PATCH.OLD_DETECTOR + "\n")
        self.assertTrue(PATCH.patch_host_key_prompt((3007, 15), self.shell))
        original = self.shell.read_bytes()
        self.assertFalse(PATCH.patch_host_key_prompt((3007, 15), self.shell))
        self.assertEqual(self.shell.read_bytes(), original)

    def test_unexpected_detector_fails_without_writing(self):
        original = b"KEY_VALID_RE = None\n"
        self.shell.write_bytes(original)
        with self.assertRaisesRegex(RuntimeError, "refusing to patch"):
            PATCH.patch_host_key_prompt((3007, 15), self.shell)
        self.assertEqual(self.shell.read_bytes(), original)

    def test_duplicate_detector_fails_without_writing(self):
        original = (PATCH.OLD_DETECTOR + "\n") * 2
        self.shell.write_text(original)
        with self.assertRaisesRegex(RuntimeError, "refusing to patch"):
            PATCH.patch_host_key_prompt((3007, 15), self.shell)
        self.assertEqual(self.shell.read_text(), original)

    def test_mixed_detectors_fail_without_writing(self):
        original = PATCH.OLD_DETECTOR + "\n" + PATCH.NEW_DETECTOR + "\n"
        self.shell.write_text(original)
        with self.assertRaisesRegex(RuntimeError, "refusing to patch"):
            PATCH.patch_host_key_prompt((3007, 15), self.shell)
        self.assertEqual(self.shell.read_text(), original)


if __name__ == "__main__":
    unittest.main()
