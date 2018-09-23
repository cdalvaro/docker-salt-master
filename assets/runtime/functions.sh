#!/usr/bin/env bash

# This function copies minion keys
function copy_minion_keys()
{
    echo "Copying minion keys..."

    if [ -d "${SALT_KEYS_DIR}/master" ] && [ ! -z "$(ls -A ${SALT_KEYS_DIR}/master)" ]; then
        mkdir -v -p -m 0700 ${SALT_MASTER_DIR}
        cp -v ${SALT_KEYS_DIR}/master/master.{pem,pub} ${SALT_MASTER_DIR}
        chown -v root:root ${SALT_MASTER_DIR}/master.{pem,pub}
    fi

    if [ -d "${SALT_KEYS_DIR}/minions" ] && [ ! -z "$(ls -A ${SALT_KEYS_DIR}/minions)" ]; then
        mkdir -v -p -m 0700 ${SALT_MASTER_DIR}/minions
        cp -v ${SALT_KEYS_DIR}/minions/* ${SALT_MASTER_DIR}/minions
        chown -v root:root ${SALT_MASTER_DIR}/minions/*
    fi
}

