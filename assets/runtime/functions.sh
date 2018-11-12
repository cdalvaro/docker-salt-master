#!/usr/bin/env bash

set -e
source ${SALT_RUNTIME_DIR}/env-defaults.sh

# Execute a command as SALT_USER
function exec_as_salt()
{
  if [[ $(whoami) == ${SALT_USER} ]]; then
    $@
  else
    sudo -HEu ${SALT_USER} "$@"
  fi
}

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

# This function replaces placeholders with values
# $1: file with placeholders to replace
# $x: placeholders to replace
function update_template()
{
  local FILE=${1?missing argument}
  shift

  [[ ! -f ${FILE} ]] && return 1

  local VARIABLES=($@)
  local USR=$(stat -c %U ${FILE})
  local tmp_file=$(mktemp)
  cp -a "${FILE}" ${tmp_file}

  local variables
  for variable in ${VARIABLES[@]}; do
    sed -ri "s|[{}]{2}$variable[}]{2}|\${$variable}|g" ${tmp_file}
  done

  # Replace placeholders
  (
    export ${VARIABLES[@]}
    local IFS=":"; sudo -HEu ${USR} envsubst "${VARIABLES[*]/#/$}" < ${tmp_file} > ${FILE}
  )

  rm -f ${tmp_file}
}

# This function configures containers timezone
function configure_timezone()
{
  echo "Configuring container timezone ..."

  # Perform sanity check of provided timezone value
  if [ -e /usr/share/zoneinfo/${TIMEZONE} ]; then
    echo "Setting TimeZone -> ${TIMEZONE} ..."

    # Set localtime
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

    # Set timezone
    echo ${TIMEZONE} > /etc/timezone
  else
    echo "Timezone: '${TIMEZONE}' is not valid. Check available timezones at: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
    return 1
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
  echo "Setting up salt keys ..."
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

  exec_as_salt cp -p ${SALT_RUNTIME_DIR}/config/master.yml ${SALT_ROOT_DIR}/master

  # Update main configuration
  update_template ${SALT_ROOT_DIR}/master \
    SALT_USER \
    SALT_LOG_LEVEL \
    SALT_LEVEL_LOGFILE \
    SALT_LOGS_DIR \
    SALT_BASE_DIR \
    SALT_CACHE_DIR \
    SALT_CONFS_DIR \
    SALT_KEYS_DIR

  # Update keys configuration
  update_template ${SALT_ROOT_DIR}/master \
    SALT_MASTER_SIGN_PUBKEY \
    SALT_MASTER_SIGN_KEY_NAME \
    SALT_MASTER_PUBKEY_SIGNATURE \
    SALT_MASTER_USE_PUBKEY_SIGNATURE
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
  configure_timezone
  configure_salt_master
  setup_salt_keys
  setup_ssh_keys
}
