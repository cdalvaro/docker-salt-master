"""
Save the Linux lock files of a Salt version, to pin the packages installed for ssh_ext_alternatives.

The lock files (requirements/static/pkg/py<MAJOR.MINOR>/linux.lock) are taken from the official Salt release sdist,
and saved as <output_dir>/<MAJOR.MINOR>.lock. There is one lock file for each Python version supported by Salt.

Usage: salt-ssh-locks.py <salt_version> <output_dir>
"""

import hashlib
import pathlib
import re
import sys
import tarfile
import tempfile
import urllib.request

salt_version, output_dir = sys.argv[1], pathlib.Path(sys.argv[2])

sdist_name = f"salt-{salt_version}.tar.gz"
sdist_url = f"https://github.com/saltstack/salt/releases/download/v{salt_version}/{sdist_name}"
with urllib.request.urlopen(f"{sdist_url}.SHA512") as response:
    expected_sha512 = response.read().decode().strip()

lock_re = re.compile(r"^[^/]+/requirements/static/pkg/py(\d+\.\d+)/linux\.lock$")
output_dir.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryFile() as sdist_file:
    with urllib.request.urlopen(sdist_url) as response:
        sdist_file.write(response.read())

    sdist_file.seek(0)
    if hashlib.sha512(sdist_file.read()).hexdigest() != expected_sha512:
        sys.exit(f"The SHA512 of {sdist_name} does not match the one published with the Salt release")

    sdist_file.seek(0)
    python_versions = []
    with tarfile.open(fileobj=sdist_file, mode="r:gz") as sdist_tar:
        for member in sdist_tar.getmembers():
            match = lock_re.match(member.name)
            # extractfile() returns None for anything that is not a regular file
            lock_file = sdist_tar.extractfile(member) if match else None
            if match and lock_file:
                (output_dir / f"{match[1]}.lock").write_bytes(lock_file.read())
                python_versions.append(match[1])

if not python_versions:
    sys.exit(f"Unable to find the lock files in {sdist_name}")

print("\n".join(sorted(python_versions, key=lambda version: tuple(map(int, version.split("."))))))
