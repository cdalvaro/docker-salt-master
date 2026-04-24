# Basic Tests

Checks performed by `tests/basic/test.sh`:

- **salt-master version** - Verifies that the installed `salt-master` version matches the expected `SALT_VERSION`.
- **salt-minion version** - Verifies that the installed `salt-minion` version matches the expected `SALT_VERSION`.
- **salt-minion not running by default** - Confirms that `salt-minion` is not started automatically inside the container.
- **salt-minion connectivity** - Starts an external `salt-minion` and verifies it can ping the master (`test.ping`).
- **salt home permissions** - Checks that the `${SALT_HOME}` directory is owned by the `salt` user and group.
- **salt user id** - Verifies that the UID of the `salt` user inside the container matches the host `PUID`.
- **salt group id** - Verifies that the GID of the `salt` group inside the container matches the host `PGID`.
- **no ubuntu user inside the container** - Confirms that the `ubuntu` system user is not present inside the container.
- **no ubuntu group inside the container** - Confirms that the `ubuntu` system group is not present inside the container.
