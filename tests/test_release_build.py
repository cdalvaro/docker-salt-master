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

    def test_basic_salt_versions(self):
        # Run the real parsing/comparison block, mocking only the Salt CLI output.
        basic = (ROOT / "tests/basic/test.sh").read_text()
        block = basic.split("# Check salt versions\n", 1)[1].split(
            'echo "==> Checking salt-minion service ..."', 1
        )[0]
        script = f'''
        IMAGE_NAME=unused PLATFORM=linux/amd64 SCRIPT_PATH="{ROOT}/tests/basic"
        source "{ROOT}/tests/lib/common.sh"
        container_log() {{ :; }}
        master_log() {{ :; }}
        builtin_minion_log() {{ :; }}
        minion_log() {{ :; }}
        SALT_VERSION="$1"; MASTER_VERSION="$2"; MINION_VERSION="$3"
        docker-exec() {{
          if [[ "$1" == salt-master ]]; then
            printf 'Salt Version:\\n          Salt: %s\\n' "$MASTER_VERSION"
          else
            printf 'Salt Version:\\n          Salt: %s\\n' "$MINION_VERSION"
          fi
        }}
        ''' + block
        cases = [
            ("3008.3", "3008.3", 0),
            ("3008.3-1", "3008.3-1", 0),
            ("3008.3-1", "3008.3", 1),
            ("3008.3", "3008.3-1", 1),
            ("3008.3-1", "3008.3-2", 1),
            ("3008.0rc4", "3008.0rc4", 0),
            ("3008.0rc4", "3008.0rc4-0-gabcdef0", 0),
            ("3008.0rc4", "3008.0rc4+0.gabcdef0", 0),
            ("3008.0rc4", "3008.0rc3-0-gabcdef0", 1),
            ("3008.0rc4", "3008.0rc4-1-gabcdef0", 1),
            ("3008.0rc4", "3008.0rc4+1.gabcdef0", 1),
            ("3008.0rc4", "3008.0rc4-1", 1),
            ("3008.0rc4", "3008.0rc4-0-gabcdef0-dirty", 1),
            ("3008.0rc4-1", "3008.0rc4-1", 0),
            ("3008.0rc4", "3008.0", 1),
            ("3008.0", "3008.0rc4", 1),
            ("3008.3-1", "", 1),
        ]
        for expected, actual, status in cases:
            for target in ("master", "minion"):
                with self.subTest(expected=expected, actual=actual, target=target):
                    master, minion = (actual, expected) if target == "master" else (expected, actual)
                    result = subprocess.run(
                        ["bash", "-e", "-c", script, "version-regression", expected, master, minion],
                        capture_output=True, text=True, check=False,
                    )
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    if status == 0:
                        self.assertIn(f"Expected: {expected}\n", result.stdout)

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
