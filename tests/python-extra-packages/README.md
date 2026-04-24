# Python Extra Packages Tests

Checks performed by `tests/python-extra-packages/test.sh`:

- **Install via `PYTHON_PACKAGES_FILE`** - Starts the container with a `requirements.txt` file mounted and verifies that:
  - The package `docker==6.1.3` is installed at the exact requested version.
  - The package `redis` is installed (latest available version).

- **Install via `PYTHON_PACKAGES`** - Starts the container with packages specified as an environment variable and verifies that:
  - The package `docker==6.1.3` is installed at the exact requested version.

- **`PYTHON_PACKAGES_FILE` takes precedence over `PYTHON_PACKAGES`** - Starts the container with both `PYTHON_PACKAGES_FILE` and `PYTHON_PACKAGES` set, and verifies that:
  - The package `docker==6.1.3` is installed (from the requirements file).
  - The package `redis` is installed (from the requirements file).
  - The package `mysql-python` (only listed in `PYTHON_PACKAGES`) is **not** installed, confirming that `PYTHON_PACKAGES_FILE` takes precedence.
