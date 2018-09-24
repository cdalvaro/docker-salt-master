#!/usr/bin/env bash

set -e

echo "Loading ${SALT_RUNTIME_DIR}/env-defaults.sh"
source ${SALT_RUNTIME_DIR}/env-defaults.sh

# This function copies minion keys
function copy_minion_keys()
{
    echo "Copying minion keys..."

    if [ -d "${SALT_KEYS_DIR}/master" ] && [ ! -z "$(ls -A ${SALT_KEYS_DIR}/master)" ]; then
        mkdir -v -p -m 0700 ${SALT_MASTER_DIR}
        cp -v ${SALT_KEYS_DIR}/master/master.{pem,pub} ${SALT_MASTER_DIR}
        chown -v ${SALT_USER}:${SALT_USER} ${SALT_MASTER_DIR}/master.{pem,pub}
    fi

    if [ -d "${SALT_KEYS_DIR}/minions" ] && [ ! -z "$(ls -A ${SALT_KEYS_DIR}/minions)" ]; then
        mkdir -v -p -m 0700 ${SALT_MASTER_DIR}/minions
        cp -v ${SALT_KEYS_DIR}/minions/* ${SALT_MASTER_DIR}/minions
        chown -v ${SALT_USER}:${SALT_USER} ${SALT_MASTER_DIR}/minions/*
    fi
}

# This functions cofigures master service
function configure_salt_master()
{
    echo "Configuring salt-master..."
    # https://docs.saltstack.com/en/latest/ref/configuration/master.html

    local SALT_ROOT_DIR=/etc/salt

    # Backup file
    if [ ! -f ${SALT_ROOT_DIR}/master.backup ]; then
        cp -pv ${SALT_ROOT_DIR}/master ${SALT_ROOT_DIR}/master.backup
    else
        cp -pv ${SALT_ROOT_DIR}/master.backup ${SALT_ROOT_DIR}/master
    fi

    # Set env variables
    sed -i \
        -e "s|^[#]*log_level:.*$|log_level: ${SALT_LOG_LEVEL}|" \
        -e "s|^[#]*log_level_logfile:.*$|log_level_logfile: ${SALT_LEVEL_LOGFILE}|" \
        -e "s|^[#]*default_include:.*$|default_include: ${SALT_ROOT_DIR}/master.d/*.conf|" \
        ${SALT_ROOT_DIR}/master

    # Sync config files
    if [[ $(find ${SALT_CONFS_DIR} -type f -name '*.conf' | wc -l) -gt 0 ]]; then
        rsync --verbose --delete ${SALT_CONFS_DIR}/*.conf ${SALT_ROOT_DIR}/master.d/
        chown ${SALT_USER}:${SALT_USER} ${SALT_ROOT_DIR}/master.d/*.conf
        chmod +rx-w ${SALT_ROOT_DIR}/master.d/*.conf
    fi

}
