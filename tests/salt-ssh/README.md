# Salt SSH Tests

The tests run against an ephemeral SSH target container built from `target/Dockerfile` (Ubuntu with `openssh-server`, `python3` and a `saltssh` user with passwordless sudo). The target and the salt-master share a dedicated Docker network, so the target is reachable by its container name.

Checks:

- **salt-ssh with roster** - Starts the container with `roster` mounted at `/home/salt/data/roster`, `roster.d` mounted at `/home/salt/data/roster.d`, the `roots` directory and an empty keys directory, and verifies that:
  - `salt-ssh --version` returns the expected Salt version.
  - `roster_file` and `rosters` point to `/home/salt/data/roster` and `/home/salt/data/roster.d`.
  - `--key-deploy --passwd` succeeds for `root`, generates the `keys/ssh/salt-ssh.rsa` key pair (owned by `salt`, mode `600`), and adds the public key to the target's `authorized_keys`.
  - `test.ping` succeeds with key authentication only.
  - `grains.get host` returns the target hostname (commands run on the target, not on the master).
  - Raw shell mode (`--raw-shell 'uname -s'`) returns `Linux`.
  - `state.apply salt_ssh_test` succeeds and writes the pillar value to `/tmp/salt-ssh-test.txt` on the target.
  - `--key-deploy --passwd` succeeds for the non-root `saltssh` user, and `cmd.run whoami` returns `saltssh` without sudo and `root` with `sudo: True`.
  - The salt-ssh log file (`logs/salt/ssh`) is created.

- **Key persistence and salt-api ssh client** - Restarts the container reusing the previous keys directory, with `SALT_API_ENABLED=True` and the `ssh` netapi client enabled, and verifies that:
  - `test.ping` succeeds without deploying the key again, the public key is unchanged, and the private key is still owned by `salt` with mode `600`.
  - A `client=ssh` request to salt-api with `roster_file=api` reaches `salt-ssh-api`, a target that is only defined in `roster.d/api`.
