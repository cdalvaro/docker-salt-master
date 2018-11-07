#!/usr/bin/env bash

set -e

# Salt user
echo "Creating ${SALT_USER} user ..."
useradd -d ${SALT_HOME} -ms /bin/bash -U -G root,sudo ${SALT_USER}

# Bootstrap script options:
# https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html#command-line-options
## -M: install Salt Master by default
## -N: Do not install salt-minion
## -X: Do not start daemons after installation
## -P: Allow pip based installations
## -x: Changes the python version used to install a git version of salt
SALT_BOOTSTRAP_OPTS='-M -N -X -P -x python3'

echo "Installing saltstack ..."
wget -O bootstrap-salt.sh https://bootstrap.saltstack.com
sh bootstrap-salt.sh ${SALT_BOOTSTRAP_OPTS} stable ${SALT_VERSION}
chown -R ${SALT_USER}: ${SALT_ROOT_DIR}
