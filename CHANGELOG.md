# Changelog

This file only reflects the changes that are made in this image.
Please refer to the SaltStack [Release Notes](https://docs.saltstack.com/en/latest/topics/releases/3002.1.html) for the list of changes in SaltStack.

**3002.1**

- Upgrade `salt-master` to `3002.1` *Magnesium*
- Change Docker base image to `ubuntu:focal-20201008`

**3002**

- Upgrade `salt-master` to `3002` *Magnesium*
- Bring back support for Linux ARMv7 platform
- Remove patch for muting sudo `RLIMIT_CORE` message
- Install `pygit2` and `m2crypto` from ubuntu repositories
- Change Docker base image to `ubuntu:focal-20200925`

**3001.1**

- Upgrade `salt-master` to `3001.1` *Sodium*
- Upgrade `m2crypto` to version `0.36.0`
- Change Docker base image to `ubuntu:focal-20200720`

**3001**

- Upgrade `salt-master` to `3001` *Sodium*
- Upgrade Python to version `3.8`
- Upgrade `libgit2` to version `1.0.1`
- Change Docker base image to `ubuntu:focal-20200606`

**3000.3_2**

- Add support for local third party formulas
- Add healthcheck script
- Remove HEALTCHECK from Dockerfile

**3000.3_1**

- Add support for `salt-api` service
- Add entrypoint support to restart services
- Use previous image as Docker cache
- Add `build-arg` to Makefile

**3000.3**

- Upgrade `salt-master` to `3000.3`
- Upgrade `pygit2` to version `1.2.1`

**3000.2**

- Upgrade `salt-master` to `3000.2`
- Upgrade `pygit2` to version `1.2.0`
- Change Docker base image to `ubuntu:bionic-20200403`

**3000.1**

- Upgrade `salt-master` to `3000.1`
- Upgrade `libgit2` to version `1.0.0`
- Upgrade `pygit2` to version `1.1.1`

**3000_1**

- Add container healthcheck
- Change Docker base image to `ubuntu:bionic-20200311`

**3000**

- Upgrade `salt-master` to `3000` *Neon*
- Change Docker base image to `ubuntu:bionic-20200112`
- Upgrade pygit2 to version `1.0.3`

**2019.2.3**

- Upgrade `salt-master` to `2019.2.3`
- Change Docker base image to `ubuntu:bionic-20191202`
- Upgrade `libgit2` to version `0.28.4`
- Upgrade `pygit2` to version `1.0.2`

**2019.2.2**

- Upgrade `salt-master` to `2019.2.2`
- Change Docker base image to `ubuntu:bionic-20191010`

**2019.2.1**

- Upgrade `salt-master` to `2019.2.1`
- Change Docker base image to `ubuntu:bionic-20190912.1`
- Upgrade `libssh2` to version `1.9.0`
- Upgrade `m2crypto` to version `0.35.2`

**2019.2.0**

- Upgrade `salt-master` to `2019.2.0`
- Change Docker base image to `ubuntu:bionic-20190204`
- Upgrade Python to version `3.6`
- Upgrade `libgit2` to `0.27.8`
- Reduce image size by updating, installing and cleaning packages in one single step

**2018.3.4**

- Upgrade `salt-master` to `2018.3.4`
- Change Docker base image to `ubuntu:xenial-20190122`

**2018.3.3**

- Upgrade `salt-master` to `2018.3.3`
- Change Docker base image to `ubuntu:xenial-20181113`
- Add `GitPython` support
- Add `PyGit2` support
- Expose `/home/salt/data/logs`
- Run `salt-master` as `salt` user
- Add support for setting timezone
- Add logrotate support
- Add supervisor support
- Add cron support
- Add Docker Labels from label-schema.org
- Addressed a bug that caused the container to crash when `/home/salt/data/keys/minions` was not present

**2018.3.2**

- First version: `salt-master` `2018.3.2`
