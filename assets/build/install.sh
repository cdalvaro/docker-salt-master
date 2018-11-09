#!/usr/bin/env bash

set -e

# Install build dependencies
echo "Installing dependencies ..."
BUILD_DEPENDENCIES="gnupg git cmake gcc g++ make \
    libhttp-parser-dev libssl-dev zlib1g-dev \
    libzmq-dev libcurl4-openssl-dev libffi-dev"

apt-get install --yes --quiet --no-install-recommends ${BUILD_DEPENDENCIES}

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

# Install python packages
echo "Installing python packages ..."
pip3 install "pygit2==v${PYGIT2_VERSION}" \
             "gitpython==v${GITPYTHON_VERSION}" \
             "M2Crypto==v${M2CRYPTO_VERSION}" \
             "Mako==v${MAKO_VERSION}" \
             "pycryptodome==v${PYCRYPTODOME_VERSION}" \
             "libnacl==v${LIBNACL_VERSION}" \
             "raet==v${RAET_VERSION}"

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
SALT_BOOTSTRAP_OPTS="-M -N -X -P -x python${PYTHON_VERSION}"

echo "Installing saltstack ..."
wget -O bootstrap-salt.sh https://bootstrap.saltstack.com
sh bootstrap-salt.sh ${SALT_BOOTSTRAP_OPTS} stable ${SALT_VERSION}
chown -R ${SALT_USER}: ${SALT_ROOT_DIR}

# Configure ssh
echo "Configuring ssh ..."
sed -i -e "s|^[# ]*StrictHostKeyChecking.*$|    StrictHostKeyChecking no|" /etc/ssh/ssh_config
echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config
echo "    LogLevel ERROR" >> /etc/ssh/ssh_config
echo "#   IdentityFile salt_ssh_key" >> /etc/ssh/ssh_config
