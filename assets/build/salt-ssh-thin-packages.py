"""
Print the Python packages that salt-ssh packs into the thin, to install them for ssh_ext_alternatives.

salt.utils.thin.get_tops_python() (used by auto_detect) runs `py_bin -c "import <module>; ..."` for every
module of the thin. It is run with subprocess.Popen patched to record these modules, which are mapped to
the distributions of the salt-master Python that provide them (the ones packed into the default thin).
"""

import importlib.metadata
import importlib.util
import sys
from unittest import mock

import salt.utils.thin

modules = []


class RecordModule:
    """Fake subprocess.Popen that records the module of `import <module>; print(<module>.__file__)`."""

    def __init__(self, cmd, *args, **kwargs):
        modules.append(cmd[-1].split(";")[0].split()[-1])

    def communicate(self):
        return b"", b""


# log is patched to hide the errors about the modules that are not found
with mock.patch.object(salt.utils.thin.subprocess, "Popen", RecordModule), mock.patch.object(salt.utils.thin, "log"):
    salt.utils.thin.get_tops_python(sys.executable, ext_py_ver=[3, 0])

# Top level modules of each distribution, from its RECORD file (top_level.txt is optional)
module_distributions = {}
for distribution in importlib.metadata.distributions():
    for file in distribution.files or []:
        module_distributions.setdefault(file.parts[0].removesuffix(".py"), set()).add(distribution.metadata["Name"])

packages = set()
for module in modules:
    # Standard library modules and Python 2 backports (not installed) are not needed
    if module in sys.stdlib_module_names or importlib.util.find_spec(module) is None:
        continue
    if module not in module_distributions:
        sys.exit(f"Unable to find the distribution of the salt-ssh thin module: {module}")
    packages |= module_distributions[module]

if not packages:
    sys.exit("Unable to get the salt-ssh thin modules from salt.utils.thin.get_tops_python()")

print("\n".join(sorted(packages, key=str.lower)))
