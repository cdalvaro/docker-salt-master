#!/usr/bin/env bash

set -e
source ${SALT_RUNTIME_DIR}/env-defaults.sh

# Map salt user with host user
function map_uidgid()
{
  USERMAP_ORIG_UID=$(id -u ${SALT_USER})
  USERMAP_ORIG_GID=$(id -g ${SALT_USER})
  USERMAP_GID=${USERMAP_GID:-${USERMAP_UID:-$USERMAP_ORIG_GID}}
  USERMAP_UID=${USERMAP_UID:-$USERMAP_ORIG_UID}
  if [[ ${USERMAP_UID} != ${USERMAP_ORIG_UID} ]] || [[ ${USERMAP_GID} != ${USERMAP_ORIG_GID} ]]; then
    echo "Mapping UID and GID for ${SALT_USER}:${SALT_USER} to ${USERMAP_UID}:${USERMAP_GID} ..."
    groupmod -o -g ${USERMAP_GID} ${SALT_USER}
    sed -i -e "s|:${USERMAP_ORIG_UID}:${USERMAP_GID}:|:${USERMAP_UID}:${USERMAP_GID}:|" /etc/passwd
    find ${SALT_HOME} -path ${SALT_DATA_DIR}/\* \( ! -uid ${USERMAP_ORIG_UID} -o ! -gid ${USERMAP_ORIG_GID} \) -print0 | xargs -0 chown -h ${SALT_USER}: ${SALT_HOME}
  fi
}

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
function setup_salt_keys()
{
  echo "Setting up keys ..."

  sed -i \
      -e "s|^[# ]*master_sign_pubkey:.*$|# master_sign_pubkey -> Overrided, see Custom Settings|" \
      -e "s|^[# ]*master_sign_key_name:.*$|# master_sign_key_name -> Overrided, see Custom Settings|" \
      -e "s|^[# ]*master_pubkey_signature:.*$|# master_pubkey_signature -> Overrided, see Custom Settings|" \
      -e "s|^[# ]*master_use_pubkey_signature:.*$|# master_use_pubkey_signature -> Overrided, see Custom Settings|" \
      ${SALT_ROOT_DIR}/master

  cat >> ${SALT_ROOT_DIR}/master <<EOF
#####         Security settings        #####
############################################
master_sign_pubkey: ${SALT_MASTER_SIGN_PUBKEY}
master_sign_key_name: ${SALT_MASTER_SIGN_KEY_NAME}
master_pubkey_signature: ${SALT_MASTER_PUBKEY_SIGNATURE}
master_use_pubkey_signature: ${SALT_MASTER_USE_PUBKEY_SIGNATURE}

EOF

  if [ ! -f ${SALT_KEYS_DIR}/master.pem ]; then
    echo "Generating keys ..."
    salt-key --gen-keys master --gen-keys-dir ${SALT_KEYS_DIR}
  fi

  if [ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pem" ] && [ ${SALT_MASTER_SIGN_PUBKEY} == True ]; then
    echo "Generating signed keys ..."
    salt-key --gen-signature --auto-create --pub ${SALT_KEYS_DIR}/master.pub --signature-path ${SALT_KEYS_DIR}
  fi

  for pub_key in $(find ${SALT_KEYS_DIR} -type f -maxdepth 1); do
    if [[ ${pub_key} =~ .*\.pem$ ]]; then
      chmod 400 ${pub_key}
    else
      chmod 644 ${pub_key}
    fi
  done

  find ${SALT_KEYS_DIR}/minions* -type f -maxdepth 1 -exec chmod 644 {} \;
  find ${SALT_HOME} -path ${SALT_KEYS_DIR}/\* -prune -o -print0 | xargs -0 chown -h ${SALT_USER}:
}

# This function configures ssh keys
function setup_ssh_keys()
{
  echo "Configuring ssh ..."

  sed -i \
    -e "s|^[# ]*IdentityFile salt_ssh_key$|    IdentityFile ${SALT_KEYS_DIR}/${SALT_GITFS_SSH_PRIVATE_KEY}|" \
    /etc/ssh/ssh_config

  if [[ -f "${SALT_KEYS_DIR}/${SALT_GITFS_SSH_PRIVATE_KEY}" ]]; then
    chmod 600 "${SALT_KEYS_DIR}/${SALT_GITFS_SSH_PRIVATE_KEY}"
  fi

  if [[ -f "${SALT_KEYS_DIR}/${SALT_GITFS_SSH_PUBLIC_KEY}" ]]; then
    chmod 644 "${SALT_KEYS_DIR}/${SALT_GITFS_SSH_PUBLIC_KEY}"
  fi
}

# This functions cofigures master service
function configure_salt_master()
{
  echo "Configuring salt-master ..."
  # https://docs.saltstack.com/en/latest/ref/configuration/master.html

  # Backup file
  if [ ! -f ${SALT_ROOT_DIR}/master.backup ]; then
    cp -p ${SALT_ROOT_DIR}/master ${SALT_ROOT_DIR}/master.orig
  else
    cp -p ${SALT_ROOT_DIR}/master.orig ${SALT_ROOT_DIR}/master
  fi

  # Set env variables
  sed -i \
      -e "s|^[#]*user:.*$|user: ${SALT_USER}|" \
      -e "s|^[#]*log_level:.*$|log_level: ${SALT_LOG_LEVEL}|" \
      -e "s|^[#]*log_level_logfile:.*$|log_level_logfile: ${SALT_LEVEL_LOGFILE}|" \
      -e "s|^[#]*default_include:.*$|default_include: ${SALT_CONFS_DIR}/*.conf|" \
      -e "s|^[#]*pki_dir:.*$|pki_dir: ${SALT_KEYS_DIR}/|" \
      -e "s|/var/log/salt|${SALT_LOGS_DIR}|g" \
      ${SALT_ROOT_DIR}/master

  cat >> ${SALT_ROOT_DIR}/master <<EOF

######       Custom Settings          ######
############################################

######       Base Directories         ######
############################################
file_roots:
  base:
    - ${SALT_BASE_DIR}/salt

pillar_roots:
  base:
    - ${SALT_BASE_DIR}/pillar

EOF
}

# Initializes main directories
function initialize_datadir()
{
  echo "Configuring directories ..."
  
  # This symlink simplifies paths for loading sls files
  [[ -d /srv ]] && [[ ! -L /srv ]] && rm -rf /srv
  ln -sfnv ${SALT_BASE_DIR} /srv

  # Set Slat root permissions
  chown -R ${SALT_USER} ${SALT_ROOT_DIR}

  # Set Salt run permissions
  mkdir -p /var/run/salt
  chown -R ${SALT_USER} /var/run/salt

  # Set cache permissions
  mkdir -p /var/cache/salt/master
  chown -R salt /var/cache/salt

  # Logs directory
  [[ -d /var/log/salt ]] && [[ ! -L /var/log/salt ]] && rm -rf /var/log/salt
  mkdir -p /var/log
  ln -sfnv ${SALT_LOGS_DIR} /var/log/salt
  chown -R ${SALT_USER} ${SALT_LOGS_DIR}
}

# Initializes the system
function initialize_system()
{
  map_uidgid
  initialize_datadir
  configure_salt_master
  setup_salt_keys
  setup_ssh_keys
}
