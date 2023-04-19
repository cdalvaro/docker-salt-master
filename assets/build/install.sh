#!/usr/bin/env bash

set -o errexit
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

# shellcheck source=assets/build/functions.sh
FUNCTIONS_FILE="${SALT_BUILD_DIR}/functions.sh"
source "${FUNCTIONS_FILE}"

log_info "Installing required packages and build dependencies ..."
REQUIRED_PACKAGES=(
  libssl3 zlib1g libffi7 libpcre3 libgssapi3-heimdal
)

BUILD_DEPENDENCIES=(
  make gcc g++
)

apt-get update
install_pkgs "${REQUIRED_PACKAGES[@]}" "${BUILD_DEPENDENCIES[@]}"

# Create salt user
log_info "Creating ${SALT_USER} user ..."
useradd -d "${SALT_HOME}" -ms /bin/bash -U -G root,sudo,shadow "${SALT_USER}"

# Set PATH
exec_as_salt cat >> "${SALT_HOME}/.profile" <<EOF
PATH=/usr/local/sbin:/usr/local/bin:\$PATH
EOF

# Install python3 packages
log_info "Installing python3 packages ..."
install_pkgs --quiet \
  python3-mako python3-pycryptodome python3-cherrypy3 \
  python3-git python3-requests python3-redis python3-gnupg \
  python3-mysqldb python3-dateutil python3-libnacl python3-openssl \
  python3-pygit2

# Downloading bootstrap-salt.sh script
BOOTSTRAP_VERSION='2023.04.06'
BOOTSTRAP_URL="https://github.com/saltstack/salt-bootstrap/releases/download/v${BOOTSTRAP_VERSION}/bootstrap-salt.sh"
BOOTSTRAP_FILE='bootstrap-salt.sh'
BOOTSTRAP_SHA256='994bf7e8bd92fe6d70d291c7562aff299f5651046b4e76dfa506cee0d9bb0843'

download "${BOOTSTRAP_URL}" "${BOOTSTRAP_FILE}"
check_sha256 "${BOOTSTRAP_FILE}" "${BOOTSTRAP_SHA256}"

# Bootstrap script options:
# https://docs.saltproject.io/salt/install-guide/en/latest/topics/bootstrap.html
## -M: install Salt Master by default
## -N: Do not install salt-minion
## -X: Do not start daemons after installation
## -d: Disables checking if Salt services are enabled to start on system boot
## -P: Allow pip based installations
## -p: Extra-package to install
SALT_BOOTSTRAP_OPTS=( -M -N -X -d -P -p salt-api -p salt-call )

## -I: allow insecure connections while downloading any files
is_arm32 && SALT_BOOTSTRAP_OPTS+=( -I )

log_info "Installing saltstack ..."
log_debug "Options: ${SALT_BOOTSTRAP_OPTS[@]}"
sh "${BOOTSTRAP_FILE}" ${SALT_BOOTSTRAP_OPTS[@]} git "v${SALT_VERSION}"
chown -R "${SALT_USER}": "${SALT_ROOT_DIR}"

# Patch to remove salt-minion
SALT_MINION="$(command -v salt-minion)"
if [[ -n "${SALT_MINION}" ]]; then
  log_warn "Removing salt-minion ..."
  rm -f "${SALT_MINION}"
fi

# Configure ssh
log_info "Configuring ssh ..."
sed -i -e "s|^[# ]*StrictHostKeyChecking.*$|    StrictHostKeyChecking no|" /etc/ssh/ssh_config
{
  echo "    UserKnownHostsFile /dev/null"
  echo "    LogLevel ERROR"
  echo "#   IdentityFile salt_ssh_key"
} >> /etc/ssh/ssh_config

# Configure logrotate
log_info "Configuring logrotate ..."

# move supervisord.log file to ${SALT_LOGS_DIR}/supervisor/
sed -i "s|^[#]*logfile=.*|logfile=${SALT_LOGS_DIR}/supervisor/supervisord.log ;|" /etc/supervisor/supervisord.conf

# fix "unknown group 'syslog'" error preventing logrotate from functioning
sed -i "s|^su root syslog$|su root root|" /etc/logrotate.conf

# Configure supervisor
log_info "Configuring supervisor ..."

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
apt-get purge -y --auto-remove "${BUILD_DEPENDENCIES[@]}"
apt-get clean --yes
rm -rf /var/lib/apt/lists/*

export -n DEBIAN_FRONTEND
