# Changelog

This file only reflects the changes that are made in this image.
Please refer to the [Salt 3007.12 Release Notes](https://docs.saltstack.com/en/latest/topics/releases/3007.12.html)
for the list of changes in SaltStack.

**3006.21**

- Update `salt-master` to `3006.21` _Sulfur_.

**3007.12**

- Update `salt-master` to `3007.12` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20260113`.

**3006.20**

- Update `salt-master` to `3006.20` _Sulfur_.
- Change Docker base image to `ubuntu:noble-20260113`.

**3007.11**

- Update `salt-master` to `3007.11` _Chlorine_.

**3006.19**

- Update `salt-master` to `3006.19` _Sulfur_.

**3007.10**

- Update `salt-master` to `3007.10` _Chlorine_.

**3006.18**

- Update `salt-master` to `3006.18` _Sulfur_.

**3007.9**

- Update `salt-master` to `3007.9` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20251013`.
- Update `pygit2` to version `1.18.2`.

**3007.8**

- Update `salt-master` to `3007.8` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20250910`.
- Fixed `supervisord` config.
- Restart `salt-api` when `salt-master` restarts.
- `salt-api` and `salt-minion` outputs are no longer redirected to _stdout/stderr_.
- `.log` extension has been removed from salt log files.
- Fix `logrotate` rules.
- Run `salt-api` under `salt` user.

**3007.7**

- Update `salt-master` to `3007.7` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20250716`.

**3007.6_1**

- Allow disabling SSL for the CherryPy server using the env variable `SALT_API_DISABLE_SSL`.

**3007.6**

- Update `salt-master` to `3007.6` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20250619`.

**3007.5_1**

- Fix a bug checking deprecated versions ([#304](https://github.com/cdalvaro/docker-salt-master/issues/304)).

**3007.5**

- Update `salt-master` to `3007.5` _Chlorine_.
- Update SaltGUI to version `1.32.1`.

**3007.4**

- Update `salt-master` to `3007.4` _Chlorine_.
- Update SaltGUI to version `1.32.0`.

**3007.3**

- Upgrade `salt-master` to `3007.3` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20250529`.

**3007.2_1**

- Added support for [SaltGUI](https://github.com/erwindon/SaltGUI) `1.31.0` as a separate image tagged with `-gui`. This image extends the main image with everything needed to support SaltGUI. See [README.md - SaltGUI](README.md#saltgui) for usage details.

**3007.2**

- Upgrade `salt-master` to `3007.2` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20250415.1`.

**3007.1_6**

- When `SALT_CONFS_DIR` is set to something different than the default value, `/home/salt/data/config`. A symlink is created pointing from `SALT_CONFS_DIR` to `/home/salt/data/config`. This is done to simplify the configuration files allowing to use the same configuration files in different containers.

**3007.1_5**

- Fixes an issue that prevents config-reload from working properly ([#270](https://github.com/cdalvaro/docker-salt-master/pull/270)).

**3007.1_4**

- Add support for LDAP ([#267](https://github.com/cdalvaro/docker-salt-master/pull/267)).

**3007.1_3**

- Do not create volumes inside Dockerfile. **Warning**: If keys or logs directories are not mounted, data will be lost after container deletion.

**3007.1_2**

- Revert default `salt`'s user PUID and PGID values to `1000`. Now the `ubuntu` user is deleted before `salt` user creation.
- Fixes an issue setting permissions for master keys under some platforms ([#245](https://github.com/cdalvaro/docker-salt-master/issues/245)).
- Change Docker base image to `ubuntu:noble-20240530`.

**3007.1_1**

- Change `salt` user UID to `1001` to avoid collisions with default `ubuntu` user.

**3007.1**

- Upgrade `salt-master` to `3007.1` _Chlorine_.
- Change Docker base image to `ubuntu:noble-20240429`.
- Change Supervisor's user to `root` for `salt-master` and `salt-api` services.

**3007.0_2**

- Rename `SALT_API_SERVICE_ENABLED` to `SALT_API_ENABLED`.
  `SALT_API_SERVICE_ENABLED` is still supported for backward compatibility but support will be removed starting from Salt 3008.
- Add support for built-in `salt-minion` service.
  It can be enabled by setting the `SALT_MINION_ENABLED` environment variable to `true`.

**3007.0_1**

- Add support for installing Python extra packages ([#234](https://github.com/cdalvaro/docker-salt-master/issues/234) for more details).

**3007.0**

- Upgrade `salt-master` to `3007.0` _Chlorine_.
- Change Docker base image to `ubuntu:jammy-20240227`.

**3006.7_1**

- Fix an issue setting keys directory permissions.

**3006.7**

- Upgrade `salt-master` to `3006.7` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20240212`.
- Update `pygit2` to version `1.14.1`.

**3006.6**

- Upgrade `salt-master` to `3006.6` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20240111`.
- Update `pygit2` to version `1.14.0`.

**3006.5_1**

- Fix healthcheck script.

**3006.5**

- Upgrade `salt-master` to `3006.5` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20231211.1`.
- Update `pygit2` to version `1.13.3`.

**3006.4**

- Upgrade `salt-master` to `3006.4` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20231004`.
- Upgrade `pygit2` to version `1.13.1`.

**3006.3_1**

- Fix salt home directory permissions. Issue #211

**3006.3**

- Upgrade `salt-master` to `3006.3` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20230816`.
- Upgrade `pygit2` to version `1.12.2`.

**3006.2**

- Upgrade `salt-master` to `3006.2` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20230624`.

**3006.1_1**

- Stream `salt-master` output to stdout and stderr.
- Do not capture `salt-api` output with supervisord.
- Add `.log` extension to master and api log files.
- Change stop signal for master and api processes to `TERM`.

**3006.1**

- Upgrade `salt-master` to `3006.1` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20230425`.

**3006.0**

- Upgrade `salt-master` to `3006.0` _Sulfur_.
- Change Docker base image to `ubuntu:jammy-20230308`.
- Use [_onedir_](https://docs.saltproject.io/en/latest/topics/releases/3006.0.html#onedir-packaging) system for installing salt.
- Remove support for arm32 architecture.

**3005.1-2_1**

- Fix: check GPG env variables before exiting if `gpgkeys` directory is empty.

**3005.1-2**

- Upgrade `salt-master` to `3005.1-2` _Phosphorus_.

**3005.1_2**

- Add support for GPG keys.
- Ensure `salt-minion` is not installed.
- Remove `GitPython` documentation, since it has some
  [using warnings](https://docs.saltproject.io/en/latest/topics/tutorials/gitfs.html#id2).
- Add _Development_ section to [README.md](README.md).
- CI(tests): Install `salt-minion` for integration tests.
- CI(tests): Improve log support.
- CI(tests): Always run tests.
- CI: Always perform cleanup tasks.
- CI: Improve build times.

**3005.1_1**

- If `SALT_LEVEL_LOGFILE` is not defined, then fallback to `SALT_LOG_LEVEL`.
- Do not create automatically mount points for the following paths:
  - `/home/salt/data/3pfs`
  - `/home/salt/data/config`
  - `/home/salt/data/srv`
  - This avoids creating unnecessary volumes.
- Change Docker base image to `ubuntu:jammy-20221101`.

**3005.1**

- Upgrade `salt-master` to `3005.1` _Phosphorus_.
- Upgrade `salt-bootstrap` to version `2022.10.04`.
- Change Docker base image to `ubuntu:jammy-20220815`.

**3005_1**

- Add support for setting the `salt-master` keys via Docker secrets using the environment variables:
  - `SALT_MASTER_KEY_FILE`: The path to the master-key-pair {pem,pub} files without suffixes.
  - `SALT_MASTER_SIGN_KEY_FILE`: The path to the signing-key-pair {pem,pub} without suffixes.
  - `SALT_MASTER_PUBKEY_SIGNATURE_FILE`: The path of the salt-master public key file with the pre-calculated
    signature.
- Add support for setting the `salt-api` user's password via Docker secrets using the environment.
  variable `SALT_API_USER_PASS_FILE`.
  - Note: Has priority over `SALT_API_USER_PASS`.

**3005**

- Upgrade `salt-master` to `3005` _Phosphorus_.
- Upgrade `salt-bootstrap` to version `2022.08.13`.
- Change Docker base image to `ubuntu:jammy-20220801`.
- Use `python3` default distro version.
- Install `python3-pygit2` version `1.6.1` from Ubuntu repositories.
- Remove `USERMAP_UID` and `USERMAP_GID` env variables in favor of `PUID` and `PGID`, respectively.
- CI(tests): Use `python3` version `3.10`.

**3004.2**

- Upgrade `salt-master` to `3004.2` _Silicon_.
- Remove Jinja2 patch to avoid Markup import error.

**3004.1**

- Upgrade `salt-master` to `3004.1` _Silicon_.
- Upgrade `salt-bootstrap` to version `2022.03.15`.
- Upgrade `pygit2` to version `1.9.1`.
- Upgrade `libgit2` to version `1.4.2`.
- Fix Jinja2 version to avoid Markup import error.
- Change Docker base image to `ubuntu:hirsute-20220113`.

**3004_6**

- Set the number of worker threads to start by setting `SALT_WORKER_THREADS` env variable.

**3004_5**

- Set the number of workers for the runner/wheel in the reactor by setting `SALT_REACTOR_WORKER_THREADS` env variable.

**3004_4**

- Fix an issue restarting `salt-master` processes with `supervisorctl` when reloading config.

**3004_3**

- Deprecate `USERMAP_UID` env variable in favor of `PUID`.
- Deprecate `USERMAP_GID` env variable in favor of `PGID`.
- Add `TZ` in addition to `TIMEZONE` to the list of accepted env variables.

Support for the `USERMAP_UID` and `USERMAP_GID` env variables will be removed with Salt 3005.

**3004_2**

- Support for automatically restart `salt-master` after config changes.

**3004_1**

- Install `libssh2 1.10.0` from source.
- Install `libgit2 1.3.0` from source.
- Install `pygit2 1.7.0` from pip repositories.
- Change Docker base image to `ubuntu:hirsute-20210917`.
- Upgrade Python to version `3.9`.

**3004**

- Upgrade `salt-master` to `3004` _Silicon_.
- Change Docker base image to `ubuntu:focal-20211006`.

**3003.3**

- Upgrade `salt-master` to `3003.3` _Aluminium_.
- Change Docker base image to `ubuntu:focal-20210827`.

**3003.2**

- Upgrade `salt-master` to `3003.2` _Aluminium_.
- Change Docker base image to `ubuntu:focal-20210723`.

**3003.1**

- Upgrade `salt-master` to `3003.1` _Aluminium_.
- Change Docker base image to `ubuntu:focal-20210609`.

**3003**

- Upgrade `salt-master` to `3003` _Aluminium_.
- Add python3 `timelib` `0.2.5`.
- Change Docker base image to `ubuntu:focal-20210325`.
- Replace `m2crypto` by `pycryptodome` (see [saltstack/salt#56625](https://github.com/saltstack/salt/pull/56625)).

**3002.6**

- Upgrade `salt-master` to `3002.6` _Magnesium_.

**3002.5**

- Upgrade `salt-master` to `3002.5` _Magnesium_.

**3002.4**

- Upgrade `salt-master` to `3002.4` _Magnesium_.

**3002.3**

- Upgrade `salt-master` to `3002.3` _Magnesium_.

**3002.2**

- Upgrade `salt-master` to `3002.2` _Magnesium_.

**3002.1**

- Upgrade `salt-master` to `3002.1` _Magnesium_.
- Change Docker base image to `ubuntu:focal-20201008`.
- Fix issue changing _read-only_ directories ownership.
  ([@Kidswiss](https://github.com/Kidswiss) - [#47](https://github.com/cdalvaro/docker-salt-master/pull/47))

**3002**

- Upgrade `salt-master` to `3002` _Magnesium_.
- Bring back support for Linux ARMv7 platform.
- Remove patch for muting sudo `RLIMIT_CORE` message.
- Install `pygit2` and `m2crypto` from ubuntu repositories.
- Change Docker base image to `ubuntu:focal-20200925`.

**3001.1**

- Upgrade `salt-master` to `3001.1` _Sodium_.
- Upgrade `m2crypto` to version `0.36.0`.
- Change Docker base image to `ubuntu:focal-20200720`.

**3001**

- Upgrade `salt-master` to `3001` _Sodium_.
- Upgrade Python to version `3.8`.
- Upgrade `libgit2` to version `1.0.1`.
- Change Docker base image to `ubuntu:focal-20200606`.

**3000.3_2**

- Add support for local third party formulas.
- Add healthcheck script.
- Remove HEALTCHECK from Dockerfile.

**3000.3_1**

- Add support for `salt-api` service.
- Add entrypoint support to restart services.
- Use previous image as Docker cache.
- Add `build-arg` to Makefile.

**3000.3**

- Upgrade `salt-master` to `3000.3`.
- Upgrade `pygit2` to version `1.2.1`.

**3000.2**

- Upgrade `salt-master` to `3000.2`.
- Upgrade `pygit2` to version `1.2.0`.
- Change Docker base image to `ubuntu:bionic-20200403`.

**3000.1**

- Upgrade `salt-master` to `3000.1`.
- Upgrade `libgit2` to version `1.0.0`.
- Upgrade `pygit2` to version `1.1.1`.

**3000_1**

- Add container healthcheck.
- Change Docker base image to `ubuntu:bionic-20200311`.

**3000**

- Upgrade `salt-master` to `3000` _Neon_.
- Change Docker base image to `ubuntu:bionic-20200112`.
- Upgrade pygit2 to version `1.0.3`.

**2019.2.3**

- Upgrade `salt-master` to `2019.2.3`.
- Change Docker base image to `ubuntu:bionic-20191202`.
- Upgrade `libgit2` to version `0.28.4`.
- Upgrade `pygit2` to version `1.0.2`.

**2019.2.2**

- Upgrade `salt-master` to `2019.2.2`.
- Change Docker base image to `ubuntu:bionic-20191010`.

**2019.2.1**

- Upgrade `salt-master` to `2019.2.1`.
- Change Docker base image to `ubuntu:bionic-20190912.1`.
- Upgrade `libssh2` to version `1.9.0`.
- Upgrade `m2crypto` to version `0.35.2`.

**2019.2.0**

- Upgrade `salt-master` to `2019.2.0`.
- Change Docker base image to `ubuntu:bionic-20190204`.
- Upgrade Python to version `3.6`.
- Upgrade `libgit2` to `0.27.8`.
- Reduce image size by updating, installing and cleaning packages in one single step.

**2018.3.4**

- Upgrade `salt-master` to `2018.3.4`.
- Change Docker base image to `ubuntu:xenial-20190122`.

**2018.3.3**

- Upgrade `salt-master` to `2018.3.3`.
- Change Docker base image to `ubuntu:xenial-20181113`.
- Add `GitPython` support.
- Add `PyGit2` support.
- Expose `/home/salt/data/logs`.
- Run `salt-master` as `salt` user.
- Add support for setting timezone.
- Add logrotate support.
- Add supervisor support.
- Add cron support.
- Add Docker Labels from _label-schema.org_.
- Addressed a bug that caused the container to crash when `/home/salt/data/keys/minions` was not present.

**2018.3.2**

- First version: `salt-master` `2018.3.2`.
