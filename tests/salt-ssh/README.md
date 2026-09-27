# Salt SSH Tests

The tests run against an ephemeral SSH target container built from `target/Dockerfile` (Ubuntu with `openssh-server`, `python3` and a `saltssh` user with passwordless sudo). The target and the salt-master share a dedicated Docker network, so the target is reachable by its container name.

Checks:

- **salt-ssh with roster** - Starts the container with the `salt-ssh` directory (`roster` and `roster.d/`) mounted read-only at the default `SALT_SSH_DIR` (`/home/salt/data/salt-ssh`), the `roots` directory and an empty keys directory, and verifies that:
  - `salt-ssh --version` returns the expected Salt version.
  - `roster_file` and `rosters` point to `/home/salt/data/salt-ssh/roster` and `/home/salt/data/salt-ssh/roster.d`.
  - The ssh client `UserKnownHostsFile` is `keys/ssh/known_hosts` (`/home/salt/data/keys/ssh/known_hosts`).
  - `-i --key-deploy --passwd` succeeds for `root`, generates the `keys/ssh/salt-ssh.rsa` key pair (owned by `salt`, mode `600`), adds the public key to the target's `authorized_keys`, and stores the target host key in `keys/ssh/known_hosts`.
  - `test.ping` succeeds with key authentication only.
  - `grains.get host` returns the target hostname (commands run on the target, not on the master).
  - Raw shell mode (`--raw-shell salt-ssh-root uname -s`) returns `Linux`.
  - Host keys are checked: `salt-ssh-new-host` (the same target, reached through a network alias that is not in `known_hosts`) is rejected, and `salt-ssh -i` accepts it and stores its host key in `known_hosts`.
  - `state.apply salt_ssh_test` succeeds and writes the pillar value to `/tmp/salt-ssh-test.txt` on the target.
  - `--key-deploy --passwd` succeeds for the non-root `saltssh` user, and `cmd.run whoami` returns `saltssh` without sudo and `root` with `sudo: True`.
  - The salt-ssh log file (`logs/salt/ssh`) is created.

- **Custom `SALT_SSH_DIR`, `ssh_options`, key persistence and salt-api ssh client** - Restarts the container with `SALT_SSH_DIR` set to a custom path (where the `salt-ssh` directory is mounted read-only), a `config/ssh.conf` that sets `UserKnownHostsFile` through `ssh_options` to `/tmp/known_hosts`, reusing the previous keys directory, with `SALT_API_ENABLED=True` and the `ssh` netapi client enabled, and verifies that:
  - `roster_file` and `rosters` point to the `roster` and `roster.d` inside the custom `SALT_SSH_DIR`.
  - The target is rejected even though it is in the default `keys/ssh/known_hosts`, because salt-ssh uses the file set through `ssh_options`.
  - `salt-ssh -i` `test.ping` succeeds without deploying the key again, the public key is unchanged, the private key is still owned by `salt` with mode `600`, and the target host key is stored in `/tmp/known_hosts`.
  - A `client=ssh` request to salt-api's `/run` endpoint, with eauth credentials and `roster_file=api`, reaches `salt-ssh-api`, a target that is only defined in `roster.d/api`.
