# Salt API Tests

Checks:

- **Empty `SALT_API_USER`** - When `SALT_API_USER` is explicitly set to an empty string, the variable remains empty inside the container.

- **Authentication via `SALT_API_USER_PASS`** - Starts the container with `SALT_API_ENABLED=True` and the API user password supplied via the `SALT_API_USER_PASS` environment variable, and verifies that:
  - A valid token is returned by `POST /login` via `curl`.
  - A `runner/test.stream` command executed via `curl` returns a successful response.

- **Authentication via `SALT_API_USER_PASS_FILE`** - Starts the container with the API user password supplied as a mounted secret file via `SALT_API_USER_PASS_FILE`, and verifies that:
  - A valid token is returned by `POST /login` via `curl`.
  - A `runner/test.stream` command executed via `curl` returns a successful response.

- **`salt-pepper` integration** - Installs `salt-pepper`, starts an external `salt-minion`, and verifies that `pepper test.ping` succeeds against the minion.
