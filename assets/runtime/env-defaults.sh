#!/usr/bin/env bash

# https://docs.saltstack.com/en/latest/ref/configuration/master.html

#####         Logging settings       #####
# https://docs.saltstack.com/en/latest/ref/configuration/master.html#master-logging-settings
SALT_LOG_LEVEL=${SALT_LOG_LEVEL:-warning}
SALT_LEVEL_LOGFILE=${SALT_LEVEL_LOGFILE:-warning}

#####        Security settings       #####
# https://docs.saltstack.com/en/latest/ref/configuration/master.html#master-security-settings
SALT_MASTER_SIGN_PUBKEY=${SALT_MASTER_SIGN_PUBKEY:-False}
SALT_MASTER_USE_PUBKEY_SIGNATURE=${SALT_MASTER_USE_PUBKEY_SIGNATURE:-False}
SALT_MASTER_SIGN_KEY_NAME=${SALT_MASTER_SIGN_KEY_NAME:-master_sign}
SALT_MASTER_PUBKEY_SIGNATURE=${SALT_MASTER_PUBKEY_SIGNATURE:-master_pubkey_signature}
