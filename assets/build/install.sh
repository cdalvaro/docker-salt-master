#!/usr/bin/env bash

set -o errexit
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

# shellcheck source=assets/build/functions.sh
FUNCTIONS_FILE="${SALT_BUILD_DIR}/functions.sh"
source "${FUNCTIONS_FILE}"

log_info "Installing required packages and build dependencies ..."
REQUIRED_PACKAGES=(
  binutils patchelf libldap-common
)

BUILD_DEPENDENCIES=(
  gcc libsasl2-dev libldap2-dev
)

log_info "Adding salt repository..."
add_salt_repository

apt-get update
install_pkgs "${REQUIRED_PACKAGES[@]}" "${BUILD_DEPENDENCIES[@]}"

# Remove ubuntu user if exists
if getent passwd ubuntu >/dev/null 2>&1; then
  log_info "Removing ubuntu user ..."
  userdel --remove ubuntu
fi

if getent group ubuntu >/dev/null 2>&1; then
  log_info "Removing ubuntu group ..."
  groupdel ubuntu
fi

# Create salt user
# https://manpages.ubuntu.com/manpages/xenial/en/man8/useradd.8.html
log_info "Creating ${SALT_USER} user ..."
useradd --home-dir "${SALT_HOME}" --create-home \
  --shell /bin/bash --user-group "${SALT_USER}" \
  --groups shadow

# Set PATH
exec_as_salt cat >>"${SALT_HOME}/.profile" <<EOF
PATH=/usr/local/sbin:/usr/local/bin:\$PATH
EOF

# Install salt packages
log_info "Installing salt packages ..."
install_pkgs salt-master="${SALT_VERSION}" salt-minion="${SALT_VERSION}" salt-api="${SALT_VERSION}"

# Install python packages
log_info "Installing python packages ..."
# FIXME: Downgrade to pip 22.3.1 for bug: https://github.com/saltstack/salt/issues/65025
salt-pip install pip==22.3.1
salt-pip install pygit2==1.14.1
salt-pip install python-ldap

# Configure ssh
log_info "Configuring ssh ..."
sed -i -e "s|^[# ]*StrictHostKeyChecking.*$|    StrictHostKeyChecking no|" /etc/ssh/ssh_config
{
  echo "    UserKnownHostsFile /dev/null"
  echo "    LogLevel ERROR"
  echo "#   IdentityFile salt_ssh_key"
} >>/etc/ssh/ssh_config

SUPERVISOR_CONFIG_FILE=/etc/supervisor/supervisord.conf

# Configure logrotate
log_info "Configuring logrotate ..."

# move supervisord.log file to ${SALT_LOGS_DIR}/supervisor/
sed -i "s|^[#]*logfile=.*|logfile=${SALT_LOGS_DIR}/supervisor/supervisord.log ;|" "${SUPERVISOR_CONFIG_FILE}"

# fix "unknown group 'syslog'" error preventing logrotate from functioning
sed -i "s|^su root syslog$|su root root|" /etc/logrotate.conf

# Configure supervisor
log_info "Configuring supervisor ..."

# run supervisord as root
if grep -E "^user=" "${SUPERVISOR_CONFIG_FILE}"; then
  sed -i "s|^user=.*|user=root|" "${SUPERVISOR_CONFIG_FILE}"
else
  sed -i "s|^\[supervisord\]\$|[supervisord]\nuser=root|" "${SUPERVISOR_CONFIG_FILE}"
fi

# configure supervisord to start salt-master
cat >/etc/supervisor/conf.d/salt-master.conf <<EOF
[program:salt-master]
priority=5
directory=${SALT_HOME}
environment=HOME=${SALT_HOME}
command=/usr/bin/salt-master
user=root
autostart=true
autorestart=true
stopsignal=TERM
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# configure supervisord to start crond
cat >/etc/supervisor/conf.d/cron.conf <<EOF
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
((${#BUILD_DEPENDENCIES[@]} != 0)) && apt-get purge -y --auto-remove "${BUILD_DEPENDENCIES[@]}"
apt-get clean --yes
rm -rf /var/lib/apt/lists/*

export -n DEBIAN_FRONTEND

# Set home directory permissions
log_info "Setting ${SALT_USER} home directory permissions ..."
chown -R "${SALT_USER}:${SALT_USER}" "${SALT_HOME}"
