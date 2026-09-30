"""
Save the Linux lock files of a Salt version, to pin the packages installed for ssh_ext_alternatives.

The lock files (requirements/static/pkg/py<MAJOR.MINOR>/linux.lock) are taken from the Salt sdist published on PyPI,
and saved as <output_dir>/<MAJOR.MINOR>.lock. There is one lock file for each Python version supported by Salt.

Usage: salt-ssh-locks.py <salt_version> <output_dir>
"""

import hashlib
import json
import pathlib
import re
import sys
import tarfile
import tempfile
import urllib.request

salt_version, output_dir = sys.argv[1], pathlib.Path(sys.argv[2])

with urllib.request.urlopen(f"https://pypi.org/pypi/salt/{salt_version}/json") as response:
    release = json.load(response)

sdists = [url for url in release["urls"] if url["packagetype"] == "sdist"]
if len(sdists) != 1:
    sys.exit(f"Unable to find the sdist of salt {salt_version} on PyPI")
sdist = sdists[0]

lock_re = re.compile(r"^[^/]+/requirements/static/pkg/py(\d+\.\d+)/linux\.lock$")
output_dir.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryFile() as sdist_file:
    with urllib.request.urlopen(sdist["url"]) as response:
        sdist_file.write(response.read())

    sdist_file.seek(0)
    if hashlib.sha256(sdist_file.read()).hexdigest() != sdist["digests"]["sha256"]:
        sys.exit(f"The SHA256 of {sdist['filename']} does not match the one published on PyPI")

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
    sys.exit(f"Unable to find the lock files in {sdist['filename']}")

print("\n".join(sorted(python_versions, key=lambda version: tuple(map(int, version.split("."))))))
