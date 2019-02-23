#!/usr/bin/env bash

set -e

source ${SALT_BUILD_DIR}/functions.sh

# Install build dependencies
echo "Installing dependencies ..."
BUILD_DEPENDENCIES="cmake gcc g++ make \
    libhttp-parser-dev libssl-dev zlib1g-dev \
    libcurl4-openssl-dev libffi-dev swig"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends ${BUILD_DEPENDENCIES}

# Create salt user
echo "Creating ${SALT_USER} user ..."
useradd -d ${SALT_HOME} -ms /bin/bash -U -G root,sudo ${SALT_USER}

# Set PATH
exec_as_salt cat >> ${SALT_HOME}/.profile <<EOF
PATH=/usr/local/sbin:/usr/local/bin:\$PATH
EOF

# Compile libssh2
echo "Building libssh2 v${LIBSSH2_VERSION} ..."
wget https://github.com/libssh2/libssh2/archive/libssh2-${LIBSSH2_VERSION}.tar.gz
tar xzf libssh2-${LIBSSH2_VERSION}.tar.gz
cd libssh2-libssh2-${LIBSSH2_VERSION}/
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DENABLE_ZLIB_COMPRESSION=ON .
cmake --build . --target install

# Compile libgit2
echo "Building libgit2 v${LIBGIT2_VERSION} ..."
wget https://github.com/libgit2/libgit2/archive/v${LIBGIT2_VERSION}.tar.gz
tar xzf v${LIBGIT2_VERSION}.tar.gz
cd libgit2-${LIBGIT2_VERSION}/
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBUILD_CLAR=OFF -DTHREADSAFE=ON .
cmake --build . --target install

# Bootstrap script options:
# https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html#command-line-options
## -M: install Salt Master by default
## -N: Do not install salt-minion
## -X: Do not start daemons after installation
## -P: Allow pip based installations
## -x: Changes the python version used to install a git version of salt
SALT_BOOTSTRAP_OPTS="-M -N -X -P -x python${PYTHON_VERSION}"

echo "Installing saltstack ..."
wget -O bootstrap-salt.sh https://bootstrap.saltstack.com
sh bootstrap-salt.sh ${SALT_BOOTSTRAP_OPTS} git v${SALT_VERSION}
chown -R ${SALT_USER}: ${SALT_ROOT_DIR}

# Install python3 packages
echo "Installing python3 packages ..."
DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
python3-mako python3-pycryptodome python3-cherrypy3 python3-git python3-u-msgpack \
python3-ioflo python3-redis python3-gnupg python3-mysqldb python3-dateutil python3-timelib \
python3-raet python3-libnacl

# Install pip3 python packages
echo "Installing pip3 python packages ..."
pip3 install "pygit2==v${PYGIT2_VERSION}" \
             "M2Crypto==v${M2CRYPTO_VERSION}"

# Configure ssh
echo "Configuring ssh ..."
sed -i -e "s|^[# ]*StrictHostKeyChecking.*$|    StrictHostKeyChecking no|" /etc/ssh/ssh_config
echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config
echo "    LogLevel ERROR" >> /etc/ssh/ssh_config
echo "#   IdentityFile salt_ssh_key" >> /etc/ssh/ssh_config

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
command=/usr/bin/salt-master
user=${SALT_USER}
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

# purge build dependencies and cleanup apt
DEBIAN_FRONTEND=noninteractive apt-get clean --yes
rm -rf /var/lib/apt/lists/*
