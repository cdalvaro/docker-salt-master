# Salt SSH Tests

The tests run against an ephemeral SSH target container built from `target/Dockerfile` (Ubuntu with `openssh-server`, `python3` and a `saltssh` user with passwordless sudo). The target and the salt-master share a dedicated Docker network, so the target is reachable by its container name.

Checks:

- **salt-ssh with roster** - Starts the container with the `salt-ssh` directory (`roster` and `roster.d/`) mounted at the default `SALT_SSH_DIR` (`/home/salt/data/salt-ssh`), the `roots` directory and an empty keys directory, and verifies that:
  - `salt-ssh --version` returns the expected Salt version.
  - `roster_file` and `rosters` point to `/home/salt/data/salt-ssh/roster` and `/home/salt/data/salt-ssh/roster.d`.
  - `--key-deploy --passwd` succeeds for `root`, generates the `keys/ssh/salt-ssh.rsa` key pair (owned by `salt`, mode `600`), and adds the public key to the target's `authorized_keys`.
  - `test.ping` succeeds with key authentication only.
  - `grains.get host` returns the target hostname (commands run on the target, not on the master).
  - Raw shell mode (`--raw-shell 'uname -s'`) returns `Linux`.
  - `state.apply salt_ssh_test` succeeds and writes the pillar value to `/tmp/salt-ssh-test.txt` on the target.
  - `--key-deploy --passwd` succeeds for the non-root `saltssh` user, and `cmd.run whoami` returns `saltssh` without sudo and `root` with `sudo: True`.
  - The salt-ssh log file (`logs/salt/ssh`) is created.

- **Custom `SALT_SSH_DIR`, key persistence and salt-api ssh client** - Restarts the container with `SALT_SSH_DIR` set to a custom path (where the `salt-ssh` directory is mounted), reusing the previous keys directory, with `SALT_API_ENABLED=True` and the `ssh` netapi client enabled, and verifies that:
  - `roster_file` and `rosters` point to the `roster` and `roster.d` inside the custom `SALT_SSH_DIR`.
  - `test.ping` succeeds without deploying the key again, the public key is unchanged, and the private key is still owned by `salt` with mode `600`.
  - A `client=ssh` request to salt-api's `/run` endpoint, with eauth credentials and `roster_file=api`, reaches `salt-ssh-api`, a target that is only defined in `roster.d/api`. Credentials are used instead of a token because token authentication does not work with the `ssh` client in Salt 3008.2.
