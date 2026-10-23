"""Run with python3 tests/test_release_build.py (stdlib only)."""

import contextlib
import hashlib
import io
import pathlib
import runpy
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ReleaseBuildTests(unittest.TestCase):
    def test_release_lock_files(self):
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w:gz") as tar:
            for version in ("3.9", "3.10"):
                member = tarfile.TarInfo(f"salt-3008.3.post1/requirements/static/pkg/py{version}/linux.lock")
                content = b"certifi==2026.10.19\n"
                member.size = len(content)
                tar.addfile(member, io.BytesIO(content))
        data = archive.getvalue()
        url = "https://github.com/saltstack/salt/releases/download/v3008.3-1/salt-3008.3-1.tar.gz"
        for valid in (True, False):
            with self.subTest(valid_checksum=valid), tempfile.TemporaryDirectory() as tmp:
                checksum = hashlib.sha512(data).hexdigest() if valid else "0" * 128
                responses = {url: data, url + ".SHA512": checksum.encode()}
                output = io.StringIO()
                with patch.object(sys, "argv", ["salt-ssh-locks.py", "3008.3-1", tmp]), \
                        patch("urllib.request.urlopen", side_effect=lambda request: io.BytesIO(responses[request])), \
                        contextlib.redirect_stdout(output):
                    if valid:
                        runpy.run_path(str(ROOT / "assets/build/salt-ssh-locks.py"))
                        self.assertEqual(output.getvalue(), "3.9\n3.10\n")
                        self.assertEqual((pathlib.Path(tmp) / "3.10.lock").read_bytes(), content)
                    else:
                        with self.assertRaisesRegex(SystemExit, "SHA512"):
                            runpy.run_path(str(ROOT / "assets/build/salt-ssh-locks.py"))
                        self.assertEqual(list(pathlib.Path(tmp).iterdir()), [])

    def test_image_revision_guards(self):
        # Mock only git's read output; execute the real shell guard functions.
        git = '''
        git() {
          if [[ "$1" == diff ]]; then
            if [[ "$*" == *VERSION_LTS* ]]; then
              [[ "$BUMP" == yes ]] && printf 'VERSION_LTS\\n'
            elif [[ "$IMAGE_CHANGED" == yes ]]; then
              printf 'assets/build/salt-ssh-locks.py\\n'
            fi
            return 0
          fi
          if [[ "$2" == base:Dockerfile ]]; then
            printf 'ENV IMAGE_REVISION="%s"\\n' "$OLD_REVISION"
          else
            printf 'ENV IMAGE_REVISION="%s"\\n' "$NEW_REVISION"
          fi
        }
        '''
        cases = [
            ("yes", "yes", "", "", 0),
            ("yes", "yes", "", "_1", 1),
            ("no", "yes", "", "", 1),
            ("no", "yes", "", "_1", 0),
            ("no", "no", "", "", 0),
        ]
        for bump, changed, old, new, expected in cases:
            with self.subTest(bump=bump, image_changed=changed, revision=new), tempfile.TemporaryDirectory() as tmp:
                pathlib.Path(tmp, "Dockerfile").write_text(f'ENV IMAGE_REVISION="{new}"\n')
                script = f'source "{ROOT}/.github/workflows/ci_tools.sh"\n' + git
                script += f'BUMP={bump}; IMAGE_CHANGED={changed}; OLD_REVISION="{old}"; NEW_REVISION="{new}"\n'
                script += 'check_image_revision_reset base head\ncheck_image_revision_changed base head\n'
                result = subprocess.run(["bash", "-e", "-c", script], cwd=tmp, capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
