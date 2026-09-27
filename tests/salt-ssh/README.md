# Salt SSH Tests

The tests run against ephemeral SSH target containers: one built from `target/Dockerfile` (Ubuntu with `openssh-server`, `python3` and a `saltssh` user with passwordless sudo), and another one built from `target-python/Dockerfile` for the `ssh_ext_alternatives` checks. The targets and the salt-master share a dedicated Docker network, so the targets are reachable by their container names.

Checks:

- **salt-ssh with roster** - Starts the container with the `salt-ssh` directory (`roster` and `roster.d/`) mounted read-only at the default `SALT_SSH_DIR` (`/home/salt/data/salt-ssh`), the `roots` directory and an empty keys directory, and verifies that:
  - `salt-ssh --version` returns the expected Salt version.
  - `roster_file` and `rosters` point to `/home/salt/data/salt-ssh/roster` and `/home/salt/data/salt-ssh/roster.d`.
  - The ssh client `UserKnownHostsFile` is `keys/ssh/known_hosts` (`/home/salt/data/keys/ssh/known_hosts`).
  - `-i --key-deploy --passwd` succeeds for `root`, generates the `keys/ssh/salt-ssh.rsa` key pair (owned by `salt`, mode `600`), adds the public key to the target's `authorized_keys`, and stores the target host key in `keys/ssh/known_hosts`.
  - `test.ping` succeeds with key authentication only.
  - `grains.get host` returns the target hostname (commands run on the target, not on the master).
  - Raw shell mode (`--raw-shell salt-ssh-root uname -s`) returns `Linux`.
  - Host keys are checked (the extra roster entries reach the same target through network aliases):
    - `salt-ssh-new-host`, which is not in `known_hosts`, is rejected: `salt-ssh` fails with `The host key needs to be accepted`. `salt-ssh -i` accepts it and stores its host key in `known_hosts`.
    - `salt-ssh-password`, a password-only entry (`priv: null`) whose host is not in `known_hosts`, is accepted without `-i` and its host key is stored (documented exception).
    - `salt-ssh-changed`, whose host is pinned to a different host key, is rejected: `salt-ssh` fails with `Host key verification failed`.
    - `salt-ssh-changed-password`, a password-only entry for the same host, fails without sending the password: OpenSSH reports `Password authentication is disabled`.
  - `state.apply salt_ssh_test` succeeds and writes the pillar value to `/tmp/salt-ssh-test.txt` on the target.
  - `--key-deploy --passwd` succeeds for the non-root `saltssh` user, and `cmd.run whoami` returns `saltssh` without sudo and `root` with `sudo: True`.
  - The salt-ssh log file (`logs/salt/ssh`) is created.

- **Custom `SALT_SSH_DIR`, `ssh_options`, key persistence and salt-api ssh client** - Restarts the container with `SALT_SSH_DIR` set to a custom path (where the `salt-ssh` directory is mounted read-only), a `config/ssh.conf` that sets `UserKnownHostsFile` through `ssh_options` to `/tmp/known_hosts`, reusing the previous keys directory, with `SALT_API_ENABLED=True` and the `ssh` netapi client enabled, and verifies that:
  - `roster_file` and `rosters` point to the `roster` and `roster.d` inside the custom `SALT_SSH_DIR`.
  - The target is rejected (`salt-ssh` fails with `The host key needs to be accepted`) even though it is in the default `keys/ssh/known_hosts`, because salt-ssh uses the file set through `ssh_options`.
  - `salt-ssh -i` `test.ping` succeeds without deploying the key again, the public key is unchanged, the private key is still owned by `salt` with mode `600`, and the target host key is stored in `/tmp/known_hosts`.
  - A `client=ssh` request to salt-api's `/run` endpoint, with eauth credentials and `roster_file=api`, reaches `salt-ssh-api`, a target that is only defined in `roster.d/api`.

- **`ssh_ext_alternatives` with `SALT_SSH_PYTHON_VERSIONS`** - Runs only the installation of `SALT_SSH_PYTHON_VERSIONS` in new containers to check its validation. Then, starts a second target built from `target-python/Dockerfile` (`python:3.10-slim` with `openssh-server`), and restarts the container with `SALT_SSH_PYTHON_VERSIONS=3.10.20` (a patch version that is not the latest 3.10) and a `config/ssh.conf` with an `ssh_ext_alternatives` entry for Python 3.10 (`auto_detect` with `/opt/salt-ssh/python3.10/bin/python-isolated` as `py_bin`), and verifies that:
  - `SALT_SSH_PYTHON_VERSIONS` with an invalid version (`3.10.x`) or with the same `MAJOR.MINOR` twice (`3.10.20 3.10`) is rejected before installing any Python version.
  - `/opt/salt-ssh/thin-packages.txt`, generated when the image is built, has the packages required by `ssh_ext_alternatives` (`Jinja2`, `PyYAML`, `tornado`, `msgpack` and `distro`).
  - `/opt/salt-ssh/python3.10/bin/python-isolated` (without the patch version in the path) runs Python 3.10.20 as the `salt` user and imports the Salt version of `salt-master`.
  - `-i --key-deploy --passwd` `test.ping` succeeds on the Python 3.10 target (`salt-ssh-python`).
  - `grains.item pythonversion pythonpath` returns Python 3.10, and a `pythonpath` with the `python3.10/pyall` directory of the thin, so salt runs from the alternative instead of the default thin.
