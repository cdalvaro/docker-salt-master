# Changelog

This file only reflects the changes that are made in this image.
Please refer to the SaltStack [Release Notes](https://docs.saltstack.com/en/develop/topics/releases/2019.2.0.html) for the list of changes in SaltStack.

**2019.2.0**

- Upgrade SaltStack Master to `2019.2.0`
- Change Docker base image to `ubuntu:bionic-20190204`
- Upgrade Python to version `3.6`
- Upgrade `libgit2` to `0.27.8`
- Reduce image size by updating, installing and cleaning packages in one single step

**2018.3.4**

- Upgrade SaltStack Master to `2018.3.4`
- Change Docker base image to `ubuntu:xenial-20190122`

**2018.3.3**

- Upgrade SaltStack Master to `2018.3.3`
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

- First version: SaltStack Master `2018.3.2`
