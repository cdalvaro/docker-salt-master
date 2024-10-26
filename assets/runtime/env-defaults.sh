#!/usr/bin/env bash

export PUID=${PUID:-1000}
export PGID=${PGID:-1000}

export DEBUG=${DEBUG:-False}
export TIMEZONE=${TIMEZONE:-${TZ:-UTC}}

#####            Salt API            #####
export SALT_API_ENABLED=${SALT_API_ENABLED:False}
if [[ -z ${SALT_API_USER+x} ]]; then
  export SALT_API_USER=salt_api
fi
export SALT_API_CERT_CN=${SALT_API_CERT_CN:-localhost}

#####           Salt Minion          #####
export SALT_MINION_ENABLED=${SALT_MINION_ENABLED:-False}
export SALT_MINION_ID=${SALT_MINION_ID:-builtin.minion}
export SALT_MINION_CONFS_DIR="${SALT_DATA_DIR:?}/minion_config"
export SALT_MINION_KEYS_DIR="${SALT_KEYS_DIR:?}/${SALT_MINION_ID}"

export SALT_LOG_ROTATE_FREQUENCY=${SALT_LOG_ROTATE_FREQUENCY:-weekly}
export SALT_LOG_ROTATE_RETENTION=${SALT_LOG_ROTATE_RETENTION:-52}

# https://docs.saltstack.com/en/latest/ref/configuration/master.html
export SALT_RESTART_MASTER_ON_CONFIG_CHANGE=${SALT_RESTART_MASTER_ON_CONFIG_CHANGE:-False}
export SALT_REACTOR_WORKER_THREADS=${SALT_REACTOR_WORKER_THREADS:-10}
export SALT_WORKER_THREADS=${SALT_WORKER_THREADS:-5}

#####         Logging settings       #####
# https://docs.saltstack.com/en/latest/ref/configuration/master.html#master-logging-settings
export SALT_LOG_LEVEL=${SALT_LOG_LEVEL:-warning}
export SALT_LEVEL_LOGFILE=${SALT_LEVEL_LOGFILE:-${SALT_LOG_LEVEL}}

#####        Security settings       #####
# https://docs.saltstack.com/en/latest/ref/configuration/master.html#master-security-settings
export SALT_MASTER_SIGN_PUBKEY=${SALT_MASTER_SIGN_PUBKEY:-False}
export SALT_MASTER_USE_PUBKEY_SIGNATURE=${SALT_MASTER_USE_PUBKEY_SIGNATURE:-False}
export SALT_MASTER_SIGN_KEY_NAME=${SALT_MASTER_SIGN_KEY_NAME:-master_sign}
export SALT_MASTER_PUBKEY_SIGNATURE=${SALT_MASTER_PUBKEY_SIGNATURE:-master_pubkey_signature}

# Directory where GPG keys will be looking for
export SALT_KEYS_GPGKEYS_DIR="${SALT_KEYS_DIR}/gpgkeys"
