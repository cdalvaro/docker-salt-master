# Salt SSH Tests

The tests run against ephemeral SSH targets that share a Docker network with the salt-master: one built from `target/Dockerfile` (Ubuntu with `openssh-server` and `python3`), and one built from `target-python/Dockerfile` (`python:3.10-slim`) for `ssh_ext_alternatives`.

Checks:

- **salt-ssh with roster** - Starts the container with the `salt-ssh` directory mounted read-only at the default `SALT_SSH_DIR` and an empty keys directory, and verifies that:
  - `-i --key-deploy --passwd` succeeds, generates `keys/ssh/salt-ssh.rsa`, and stores the target host key in `keys/ssh/known_hosts`.
  - `test.ping` succeeds with key authentication only.
  - `state.apply` writes a pillar value to a file on the target.
  - A host that is not in `known_hosts` is rejected (`The host key needs to be accepted`), except for password-only roster entries (`priv: null`), which accept and store its host key (documented exception).
  - A host whose key in `known_hosts` has changed is rejected (`Host key verification failed`).
  - The salt-ssh log file (`logs/salt/ssh`) is created.

- **Custom `SALT_SSH_DIR`, `ssh_options` and salt-api** - Starts a new container with a custom `SALT_SSH_DIR`, the previous keys directory, `UserKnownHostsFile` set through `ssh_options`, and salt-api with the `ssh` client enabled, and verifies that:
  - The target is rejected even though it is in `keys/ssh/known_hosts`, because salt-ssh uses the file set through `ssh_options`.
  - `test.ping` succeeds with the previous key, using the roster of the custom `SALT_SSH_DIR`.
  - A `client=ssh` request to salt-api's `/run` endpoint with `roster_file=api` reaches a target that is only defined in `roster.d/api`.

- **`SALT_SSH_PYTHON_VERSIONS`** - Checks the validation of `SALT_SSH_PYTHON_VERSIONS` in new containers, then starts a new container with `SALT_SSH_PYTHON_VERSIONS=3.10.20` and an `ssh_ext_alternatives` entry for Python 3.10, and verifies that:
  - Invalid values are rejected before installing any version: a version on a new line, the same `MAJOR.MINOR` twice, a version not supported by Salt, and the Python version of `salt-master`.
  - The Python 3.10 environment runs Python 3.10.20, has `tornado` pinned by the Salt lock file, and does not have `salt` installed.
  - `salt-ssh` runs on the Python 3.10 target from the alternative (`python3.10/pyall` in `pythonpath`).
  - After a restart, the environment is reused instead of being installed again.
