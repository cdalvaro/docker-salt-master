#!/usr/bin/env bash

set -e

# shellcheck disable=SC1091
source "${SALT_BUILD_DIR}/functions.sh"

echo "Installing build dependencies ..."
BUILD_DEPENDENCIES=(make gcc g++ cmake pkg-config)

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y "${BUILD_DEPENDENCIES[@]}"

# Install arm build dependencies
if [[ "$(uname -i)" =~ ^(arm|aarch64) ]]; then
  echo "Installing arm specific dependencies ..."
  DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    libzmq3-dev libhttp-parser-dev libssl-dev libcurl4-openssl-dev
fi

# Create salt user
echo "Creating ${SALT_USER} user ..."
useradd -d "${SALT_HOME}" -ms /bin/bash -U -G root,sudo,shadow "${SALT_USER}"

# Set PATH
exec_as_salt cat >> "${SALT_HOME}/.profile" <<EOF
PATH=/usr/local/sbin:/usr/local/bin:\$PATH
EOF

# Install python3 packages
echo "Installing python3 packages ..."
DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
  python3-mako python3-pycryptodome python3-cherrypy3 python3-git python3-requests \
  python3-redis python3-gnupg python3-mysqldb python3-dateutil python3-libnacl python3-openssl \
  python3-pygit2

pip3 install timelib==0.2.5

# Bootstrap script options:
# https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html#command-line-options
## -M: install Salt Master by default
## -N: Do not install salt-minion
## -X: Do not start daemons after installation
## -d: Disables checking if Salt services are enabled to start on system boot
## -P: Allow pip based installations
## -p: Extra-package to install
## -x: Changes the python version used to install a git version of salt
SALT_BOOTSTRAP_OPTS=( -M -N -X -d -P -p salt-api -p salt-call -x "python${PYTHON_VERSION}" )
_WGET_ARGS=()

if [[ "$(uname -i)" == 'armv7l' ]]; then
  ## -I: allow insecure connections while downloading any files
  SALT_BOOTSTRAP_OPTS+=( -I )
  _WGET_ARGS+=( --no-check-certificate )
fi

echo "Installing saltstack ..."
echo "Option: ${SALT_BOOTSTRAP_OPTS[@]}"
wget ${_WGET_ARGS[@]} -O bootstrap-salt.sh https://bootstrap.saltstack.com
sh bootstrap-salt.sh ${SALT_BOOTSTRAP_OPTS[@]} git "v${SALT_VERSION}"
chown -R "${SALT_USER}": "${SALT_ROOT_DIR}"

# Configure ssh
echo "Configuring ssh ..."
sed -i -e "s|^[# ]*StrictHostKeyChecking.*$|    StrictHostKeyChecking no|" /etc/ssh/ssh_config
{
  echo "    UserKnownHostsFile /dev/null"
  echo "    LogLevel ERROR"
  echo "#   IdentityFile salt_ssh_key"
} >> /etc/ssh/ssh_config

# Configure logrotate
echo "Configuring logrotate ..."

# move supervisord.log file to ${SALT_LOGS_DIR}/supervisor/
sed -i "s|^[#]*logfile=.*|logfile=${SALT_LOGS_DIR}/supervisor/supervisord.log ;|" /etc/supervisor/supervisord.conf

# fix "unknown group 'syslog'" error preventing logrotate from functioning
sed -i "s|^su root syslog$|su root root|" /etc/logrotate.conf

# Configure supervisor
echo "Configuring supervisor ..."

# configure supervisord to start salt-master
cat > /etc/supervisor/conf.d/salt-master.conf <<EOF
[program:salt-master]
priority=5
directory=${SALT_HOME}
environment=HOME=${SALT_HOME}
command=/usr/local/bin/salt-master
user=root
autostart=true
autorestart=true
stopsignal=QUIT
stdout_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
stderr_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
EOF

# configure supervisord to start crond
cat > /etc/supervisor/conf.d/cron.conf <<EOF
[program:cron]
priority=20
directory=/tmp
command=/usr/sbin/cron -f
user=root
autostart=true
autorestart=true
stdout_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
stderr_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
EOF

# Purge build dependencies and cleanup apt
DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove "${BUILD_DEPENDENCIES[@]}"
DEBIAN_FRONTEND=noninteractive apt-get clean --yes
rm -rf /var/lib/apt/lists/*
