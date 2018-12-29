# Changelog

This file only reflects the changes that are made in this image.
Please refer to the SaltStack [Release Notes](https://docs.saltstack.com/en/develop/topics/releases/2018.3.3.html) for the list of changes in SaltStack.

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
