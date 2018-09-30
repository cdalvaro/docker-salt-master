#!/usr/bin/env bash

set -e
source ${SALT_RUNTIME_DIR}/env-defaults.sh

# This function generates a master_sign key pair and its signature
function gen_signed_keys()
{
  local key_name=${1:-master}
  
  mkdir -p ${SALT_KEYS_DIR}/generated/
  GENERATED_KEYS_DIR=$(mktemp -d -p ${SALT_KEYS_DIR}/generated/ -t ${key_name}.XXXXX)

  salt-key --gen-keys ${key_name} --gen-keys-dir ${GENERATED_KEYS_DIR} > /dev/null 2>&1
  salt-key --gen-signature --auto-create --pub ${GENERATED_KEYS_DIR}/${key_name}.pub --signature-path ${GENERATED_KEYS_DIR} > /dev/null 2>&1

  echo -n ${GENERATED_KEYS_DIR}
}

# This function repairs keys permissions and creates keys if neaded
function setup_keys()
{
  echo "Setting up keys..."

  sed -i \
      -e "s|^[#]*master_sign_pubkey:.*$|# master_sign_pubkey -> overrided|" \
      -e "s|^[#]*master_sign_key_name:.*$|# master_sign_key_name -> overrided|" \
      -e "s|^[#]*master_pubkey_signature:.*$|# master_pubkey_signature -> overrided|" \
      -e "s|^[#]*master_use_pubkey_signature:.*$|# master_use_pubkey_signature -> overrided|" \
      ${SALT_ROOT_DIR}/master

  cat >> ${SALT_ROOT_DIR}/master <<EOF

#####         Security settings        #####
############################################
master_sign_pubkey: ${SALT_MASTER_SIGN_PUBKEY}
master_sign_key_name: ${SALT_MASTER_SIGN_KEY_NAME}
master_pubkey_signature: ${SALT_MASTER_PUBKEY_SIGNATURE}
master_use_pubkey_signature: ${SALT_MASTER_USE_PUBKEY_SIGNATURE}
EOF

  if [ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}" ] && [ ${SALT_MASTER_SIGN_PUBKEY} == True ]; then
    echo "Generating signed keys..."
    if [ ! -f ${SALT_KEYS_DIR}/master.pem ]; then
      salt-key --gen-keys master --gen-keys-dir ${SALT_KEYS_DIR}
    fi
    salt-key --gen-signature --auto-create --pub ${SALT_KEYS_DIR}/master.pub --signature-path ${SALT_KEYS_DIR}
  fi

  for pub_key in $(find ${SALT_KEYS_DIR} -type f -maxdepth 2); do
    if [[ ${pub_key} =~ .*\.pem$ ]]; then
      chmod -v 400 ${pub_key}
    else
      chmod -v 644 ${pub_key}
    fi
  done
}

# This functions cofigures master service
function configure_salt_master()
{
  echo "Configuring salt-master..."
  # https://docs.saltstack.com/en/latest/ref/configuration/master.html

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
      -e "s|^[#]*pki_dir:.*$|pki_dir: ${SALT_KEYS_DIR}/|" \
      ${SALT_ROOT_DIR}/master

  cat >> ${SALT_ROOT_DIR}/master <<EOF

######       Custom Settings          ######
############################################
EOF

  # Sync config files
  if [[ $(find ${SALT_CONFS_DIR} -type f -name '*.conf' | wc -l) -gt 0 ]]; then
    rsync --verbose --delete ${SALT_CONFS_DIR}/*.conf ${SALT_ROOT_DIR}/master.d/
    chown ${SALT_USER}:${SALT_USER} ${SALT_ROOT_DIR}/master.d/*.conf
    chmod +rx-w ${SALT_ROOT_DIR}/master.d/*.conf
  fi
}
