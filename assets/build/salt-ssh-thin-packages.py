"""
Print the Python packages that salt-ssh packs into the thin, to install them for ssh_ext_alternatives.

salt.utils.thin.get_tops_python() (used by auto_detect) returns the thin modules that a Python can import.
This script runs with the salt-master Python and maps them to the distributions that provide them.
"""

import importlib.metadata
import logging
import sys

import salt.utils.thin

# Hide the errors about the Python 2 backports that get_tops_python() always looks for
logging.disable(logging.ERROR)
modules = salt.utils.thin.get_tops_python(sys.executable, ext_py_ver=[3, 0])

distributions = importlib.metadata.packages_distributions()
# Standard library modules are not provided by any distribution
missing = [module for module in modules if module not in distributions and module not in sys.stdlib_module_names]
if missing:
    sys.exit(f"Unable to find the distributions of the salt-ssh thin modules: {', '.join(missing)}")

packages = {distribution for module in modules for distribution in distributions.get(module, [])}
if not packages:
    sys.exit("Unable to get the salt-ssh thin modules from salt.utils.thin.get_tops_python()")

print("\n".join(sorted(packages, key=str.lower)))
