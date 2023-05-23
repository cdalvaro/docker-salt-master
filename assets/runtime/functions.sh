#!/usr/bin/env bash

set -o errexit
set -o pipefail

# shellcheck source=assets/runtime/env-defaults.sh
ENV_DEFAULTS_FILE="${SALT_RUNTIME_DIR}/env-defaults.sh"
source "${ENV_DEFAULTS_FILE}"

# cdalvaro managed block string
SELF_MANAGED_BLOCK_STRING="## cdalvaro managed block"

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  exec_as_salt
#   DESCRIPTION:  Execute the pass command as the `SALT_USER` user.
#----------------------------------------------------------------------------------------------------------------------
function exec_as_salt()
{
  if [[ $(whoami) == "${SALT_USER}" ]]; then
    $@
  else
    sudo -HEu "${SALT_USER}" "$@"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_debug
#   DESCRIPTION:  Echo debug information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_debug() {
  if [[ "${DEBUG,,}" == true || "${ECHO_DEBUG,,}" == true ]]; then
    echo "[DEBUG] - $*"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_info
#   DESCRIPTION:  Echo information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_info() {
  echo "[INFO] - $*"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_warn
#   DESCRIPTION:  Echo warning information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_warn() {
  (>&2 echo "[WARN] - $*")
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_error
#   DESCRIPTION:  Echo errors to stderr.
#----------------------------------------------------------------------------------------------------------------------
function log_error()
{
  (>&2 echo "[ERROR] - $*")
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  map_uidgid
#   DESCRIPTION:  Map salt user with host user.
#----------------------------------------------------------------------------------------------------------------------
function map_uidgid()
{
  ORIG_PUID=$(id -u "${SALT_USER}")
  ORIG_PGID=$(id -g "${SALT_USER}")
  PGID=${PGID:-${PUID:-$ORIG_PGID}}
  PUID=${PUID:-$ORIG_PUID}
  if [[ "${PUID}" != "${ORIG_PUID}" ]] || [[ "${PGID}" != "${ORIG_PGID}" ]]; then
    log_info "Mapping UID and GID for ${SALT_USER}:${SALT_USER} to ${PUID}:${PGID} ..."
    groupmod -o -g "${PGID}" "${SALT_USER}"
    sed -i -e "s|:${ORIG_PUID}:${PGID}:|:${PUID}:${PGID}:|" /etc/passwd
    find "${SALT_HOME}" \
      -not -path "${SALT_CONFS_DIR}*" \
      -not -path "${SALT_KEYS_DIR}*" \
      -not -path "${SALT_BASE_DIR}*" \
      -not -path "${SALT_LOGS_DIR}*" \
      -not -path "${SALT_FORMULAS_DIR}*" \
      -path "${SALT_DATA_DIR}/*" \
      \( ! -uid "${ORIG_PUID}" -o ! -gid "${ORIG_PGID}" \) \
      -print0 | xargs -0 chown -h "${SALT_USER}": "${SALT_HOME}"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  update_template
#   DESCRIPTION:  Replace placeholders with values.
#     ARGUMENTS:
#           - 1: Template file with placeholders to replace
#           - @: Placeholder values
#----------------------------------------------------------------------------------------------------------------------
function update_template()
{
  local FILE=${1?missing argument}
  shift

  [[ ! -f "${FILE}" ]] && return 1

  local VARIABLES=( "$@" )
  local USR=$(stat -c %U "${FILE}")
  local tmp_file=$(mktemp)
  cp -a "${FILE}" "${tmp_file}"

  local variables
  for variable in "${VARIABLES[@]}"; do
    sed -ri "s|[{]{2}${variable}[}]{2}|\${${variable}}|g" "${tmp_file}"
  done

  # Replace placeholders
  (
    export "${VARIABLES[@]}"
    local IFS=":"; sudo -HEu "${USR}" envsubst "${VARIABLES[*]/#/$}" < "${tmp_file}" > "${FILE}"
  )

  rm -f "${tmp_file}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  configure_timezone
#   DESCRIPTION:  Configure containers timezone.
#----------------------------------------------------------------------------------------------------------------------
function configure_timezone()
{
  log_info "Configuring container timezone ..."

  # Perform sanity check of provided timezone value
  if [[ -e "/usr/share/zoneinfo/${TIMEZONE}" ]]; then
    log_info "Setting TimeZone -> ${TIMEZONE} ..."

    # Set localtime
    ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime

    # Set timezone
    echo "${TIMEZONE}" > /etc/timezone
  else
    log_error "Timezone: '${TIMEZONE}' is not valid. Check available timezones at: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  gen_signed_keys
#   DESCRIPTION:  Generate a master_sign key pair and its signature.
#----------------------------------------------------------------------------------------------------------------------
function gen_signed_keys()
{
  local key_name=${1:-master}

  mkdir -p "${SALT_KEYS_DIR}/generated/"
  GENERATED_KEYS_DIR=$(mktemp -d -p "${SALT_KEYS_DIR}/generated/" -t "${key_name}.XXXXX")

  salt-key --gen-keys "${key_name}" --gen-keys-dir "${GENERATED_KEYS_DIR}" > /dev/null 2>&1
  salt-key --gen-signature --auto-create --pub "${GENERATED_KEYS_DIR}/${key_name}.pub" --signature-path "${GENERATED_KEYS_DIR}" > /dev/null 2>&1

  echo -n "${GENERATED_KEYS_DIR}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  _setup_master_keys
#   DESCRIPTION:  Setup salt-master keys.
#----------------------------------------------------------------------------------------------------------------------
function _setup_master_keys()
{
  log_info " ==> Setting up master keys ..."

  if [[ -n "${SALT_MASTER_KEY_FILE}" ]]; then
    if [[ ! -f "${SALT_MASTER_KEY_FILE}.pem" || ! -f "${SALT_MASTER_KEY_FILE}.pub" ]]; then
      [[ -f "${SALT_MASTER_KEY_FILE}.pem" ]] || log_error "'${SALT_MASTER_KEY_FILE}.pem' doesn't exist"
      [[ -f "${SALT_MASTER_KEY_FILE}.pub" ]] || log_error "'${SALT_MASTER_KEY_FILE}.pub' doesn't exist"
      return 1
    fi
  fi

  if [[ ! -f "${SALT_KEYS_DIR}/master.pem" ]]; then
    if [[ -n "${SALT_MASTER_KEY_FILE}" ]]; then
      # Copy master keys provided via external files
      log_info "Linking '${SALT_MASTER_KEY_FILE}' keys to '${SALT_KEYS_DIR}/master.{pem,pub}' ..."
      ln -sfn "${SALT_MASTER_KEY_FILE}.pem" "${SALT_KEYS_DIR}/master.pem"
      ln -sfn "${SALT_MASTER_KEY_FILE}.pub" "${SALT_KEYS_DIR}/master.pub"
    else
      log_info "Generating master keys ..."
      salt-key --gen-keys master --gen-keys-dir "${SALT_KEYS_DIR}"
    fi
  else
    if [[ -n "${SALT_MASTER_KEY_FILE}" ]]; then
      # If a master key is provided via SALT_MASTER_KEY_FILE, check it is the same as the one in the keys directory
      if ! cmp -s "${SALT_MASTER_KEY_FILE}.pem" "${SALT_KEYS_DIR}/master.pem" ||
         ! cmp -s "${SALT_MASTER_KEY_FILE}.pub" "${SALT_KEYS_DIR}/master.pub"; then
        log_error "SALT_MASTER_KEY_FILE is set to '${SALT_MASTER_KEY_FILE}' but keys don't match the master keys inside '${SALT_KEYS_DIR}'."
        return 1
      fi
    fi
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  _setup_master_sign_keys
#   DESCRIPTION:  Setup salt-master sign keys.
#----------------------------------------------------------------------------------------------------------------------
function _setup_master_sign_keys()
{
  log_info " ==> Setting up master_sign keys ..."

  if [[ -n "${SALT_MASTER_SIGN_KEY_FILE}" ]]; then
    if [[ ! -f "${SALT_MASTER_SIGN_KEY_FILE}.pem" || ! -f "${SALT_MASTER_SIGN_KEY_FILE}.pub" ]]; then
      [[ -f "${SALT_MASTER_SIGN_KEY_FILE}.pem" ]] || log_error "'${SALT_MASTER_SIGN_KEY_FILE}.pem' doesn't exist"
      [[ -f "${SALT_MASTER_SIGN_KEY_FILE}.pub" ]] || log_error "'${SALT_MASTER_SIGN_KEY_FILE}.pub' doesn't exist"
      return 1
    fi
  fi

  if [[ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pem" ]]; then
    if [[ -n "${SALT_MASTER_SIGN_KEY_FILE}" ]]; then
      # Copy master_sign keys provided via external files
      log_info "Linking '${SALT_MASTER_SIGN_KEY_FILE}' keys to '${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.{pem,pub}' ..."
      ln -sfn "${SALT_MASTER_SIGN_KEY_FILE}.pem" "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pem"
      ln -sfn "${SALT_MASTER_SIGN_KEY_FILE}.pub" "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pub"
    else
      log_info "Generating signed keys ..."
      salt-key --gen-signature --auto-create --pub "${SALT_KEYS_DIR}/master.pub" --signature-path "${SALT_KEYS_DIR}"
    fi
  else
    if [[ -n "${SALT_MASTER_SIGN_KEY_FILE}" ]]; then
      # If a master_sign key-pair is provided via SALT_MASTER_SIGN_KEY_FILE, check it is the same as the one in the keys directory
      if ! cmp -s "${SALT_MASTER_SIGN_KEY_FILE}.pem" "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pem" ||
         ! cmp -s "${SALT_MASTER_SIGN_KEY_FILE}.pub" "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pub"; then
        log_error "SALT_MASTER_SIGN_KEY_FILE is set to '${SALT_MASTER_SIGN_KEY_FILE}' but keys don't match the master_sign keys inside '${SALT_KEYS_DIR}'."
        return 1
      fi
    fi
  fi

  if [[ -n "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" ]]; then
    if [[ ! -f "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" ]]; then
      log_error "SALT_MASTER_PUBKEY_SIGNATURE_FILE is set to '${SALT_MASTER_PUBKEY_SIGNATURE_FILE}' but it doesn't exist."
      return 1
    fi

    if [[ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}" ]]; then
      log_info "Linking '${SALT_MASTER_PUBKEY_SIGNATURE_FILE}' to '${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}' ..."
      ln -sfn "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" "${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}"
    else
      # If a master_pubkey_signature is provided via SALT_MASTER_PUBKEY_SIGNATURE_FILE, check it is the same as the one in the keys directory
      if ! cmp -s "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" "${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}"; then
        log_error "SALT_MASTER_PUBKEY_SIGNATURE_FILE is set to '${SALT_MASTER_PUBKEY_SIGNATURE_FILE}' but it doesn't match the ${SALT_MASTER_PUBKEY_SIGNATURE} inside '${SALT_KEYS_DIR}'."
        return 1
      fi
    fi
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  _check_and_link_gpgkey
#   DESCRIPTION:  Check and link a gpgkey if env variable is set.
#     ARGUMENTS:
#           - 1: The name of the GPG env variable
#           - 2: The target gpg file
#----------------------------------------------------------------------------------------------------------------------
function _check_and_link_gpgkey() {
  local GPGKEY_VARIABLE_NAME="$1"
  local TARGET_GPGKEY="$2"
  local SOURCE_GPGKEY="${!GPGKEY_VARIABLE_NAME}"

  [[ -n "${SOURCE_GPGKEY}" ]] || return 0

  if [[ ! -f "${SOURCE_GPGKEY}" ]]; then
    log_warn "'${GPGKEY_VARIABLE_NAME}' (=${SOURCE_GPGKEY}) is set, but file does not exist."
    return 0
  fi

  if [[ -f "${TARGET_GPGKEY}" ]] && ! cmp -s "${SOURCE_GPGKEY}" "${TARGET_GPGKEY}"; then
    log_error "'${GPGKEY_VARIABLE_NAME}' (=${SOURCE_GPGKEY}) is set and ${TARGET_GPGKEY} exists, but they dont match." \
      " Please, unset '${GPGKEY_VARIABLE_NAME}' or remove '${TARGET_GPGKEY}'."
    return 1
  fi

  log_info "Linking '${SOURCE_GPGKEY}' to '${TARGET_GPGKEY}' ..."
  mkdir -p "$(dirname "${TARGET_GPGKEY}")"
  ln -sfn "${SOURCE_GPGKEY}" "${TARGET_GPGKEY}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  _setup_gpgkeys
#   DESCRIPTION:  Setup GPG keys.
#----------------------------------------------------------------------------------------------------------------------
function _setup_gpgkeys()
{
  log_info " ==> Setting up GPG keys ..."

  local private_key="${SALT_KEYS_GPGKEYS_DIR}/private.key"
  local public_key="${SALT_KEYS_GPGKEYS_DIR}/pubkey.gpg"

  _check_and_link_gpgkey 'SALT_GPG_PRIVATE_KEY_FILE' "${private_key}"
  _check_and_link_gpgkey 'SALT_GPG_PUBLIC_KEY_FILE' "${public_key}"

  if [[ ! -d "${SALT_KEYS_GPGKEYS_DIR}" || -z "$(ls -A "${SALT_KEYS_GPGKEYS_DIR}")" ]]; then
    log_info "Could not find GPG keys. GPG setup skipped."
    return 0
  fi

  if [[ ! -f "${private_key}" || ! -f "${public_key}" ]]; then
    log_error "GPG keys are not valid. Please, check the documentation for more information:"
    log_error "  - https://github.com/cdalvaro/docker-salt-master#gpg-keys-for-renderers"
    [[ -f "${private_key}" ]] || log_error "GPG private key: '${private_key##*/}' doesn't exist"
    [[ -f "${public_key}" ]] || log_error "GPG public key: '${public_key##*/}' doesn't exist"
    return 1
  fi

  log_info "Importing GPG keys ..."

  local SALT_GPGKEYS_DIR="${SALT_ROOT_DIR}"/gpgkeys
  mkdir -p "${SALT_GPGKEYS_DIR}"
  chown "${SALT_USER}:${SALT_USER}" "${SALT_GPGKEYS_DIR}"
  chmod 700 "${SALT_GPGKEYS_DIR}"

  local GPG_COMMON_OPTS=(--no-tty --homedir="${SALT_GPGKEYS_DIR}")

  exec_as_salt gpg "${GPG_COMMON_OPTS[@]}" --import "${private_key}"
  exec_as_salt gpg "${GPG_COMMON_OPTS[@]}" --import "${public_key}"

  log_info "Setting trust level to ultimate ..."
  local key_id="$(exec_as_salt gpg "${GPG_COMMON_OPTS[@]}" --list-packets "${private_key}" | awk '/keyid:/{ print $2 }' | head -1)"
  (echo trust & echo 5 & echo y & echo quit) | exec_as_salt gpg "${GPG_COMMON_OPTS[@]}" --command-fd 0 --edit-key "${key_id}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  setup_salt_keys
#   DESCRIPTION:  Repair keys permissions and creates keys if needed.
#----------------------------------------------------------------------------------------------------------------------
function setup_salt_keys()
{
  log_info "Setting up salt keys ..."
  _setup_master_keys
  [[ "${SALT_MASTER_SIGN_PUBKEY}" == True ]] && _setup_master_sign_keys
  _setup_gpgkeys

  log_info "Setting up salt keys permissions ..."
  while IFS= read -r -d '' pub_key
  do
    if [[ "${pub_key}" =~ .*\.pem$ ]]; then
      chmod 400 "${pub_key}"
    else
      chmod 644 "${pub_key}"
    fi
  done < <(find "${SALT_KEYS_DIR}" -maxdepth 1 -type f -print0)

  find "${SALT_KEYS_DIR}/minions"* -maxdepth 1 -type f -exec chmod 644 {} \;
  find "${SALT_HOME}" -path "${SALT_KEYS_DIR}/*" -print0 | xargs -0 chown -h "${SALT_USER}":
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  configure_salt_master
#   DESCRIPTION:  Configure master service.
#----------------------------------------------------------------------------------------------------------------------
function configure_salt_master()
{
  log_info "Configuring salt-master service ..."
  # https://docs.saltstack.com/en/latest/ref/configuration/master.html

  exec_as_salt cp -p "${SALT_RUNTIME_DIR}/config/master.yml" "${SALT_ROOT_DIR}/master"

  # Update main configuration
  update_template "${SALT_ROOT_DIR}/master" \
    SALT_USER \
    SALT_LOG_LEVEL \
    SALT_LEVEL_LOGFILE \
    SALT_LOGS_DIR \
    SALT_BASE_DIR \
    SALT_CACHE_DIR \
    SALT_CONFS_DIR \
    SALT_KEYS_DIR \
    SALT_REACTOR_WORKER_THREADS \
    SALT_WORKER_THREADS

  # Update keys configuration
  update_template "${SALT_ROOT_DIR}/master" \
    SALT_MASTER_SIGN_PUBKEY \
    SALT_MASTER_SIGN_KEY_NAME \
    SALT_MASTER_PUBKEY_SIGNATURE \
    SALT_MASTER_USE_PUBKEY_SIGNATURE
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  configure_salt_api
#   DESCRIPTION:  Configure salt-api if service is set to be enabled.
#----------------------------------------------------------------------------------------------------------------------
function configure_salt_api()
{
  rm -f /etc/supervisor/conf.d/salt-api.conf
  [[ ${SALT_API_SERVICE_ENABLED,,} == true ]] || return 0

  if [[ -n "${SALT_API_USER}" ]]; then

    if [[ ${SALT_API_USER} == "${SALT_USER}" ]]; then
      log_error "SALT_API_USER cannot be the same as '${SALT_USER}'."
      return 1
    fi

    if [[ -n "${SALT_API_USER_PASS_FILE}" ]]; then
      if [[ ! -f "${SALT_API_USER_PASS_FILE}" ]]; then
        log_error "SALT_API_USER_PASS_FILE '${SALT_API_USER_PASS_FILE}' does not exist."
        return 1
      elif [[ -n "${SALT_API_USER_PASS}" ]]; then
        log_warn "SALT_API_USER_PASS_FILE and SALT_API_USER_PASS cannot be set at the same time. The first one will be used."
      fi
      SALT_API_USER_PASS="$(cat "${SALT_API_USER_PASS_FILE}")"
    fi

    if [[ -z "${SALT_API_USER_PASS}" ]]; then
      log_error "SALT_API_USER_PASS env variable must be set to create '${SALT_API_USER}' user."
      return 2
    fi

    if ! id -u "${SALT_API_USER}" &>/dev/null; then
      log_info "Creating '${SALT_API_USER}' user for salt-api ..."
      adduser --quiet --disabled-password --gecos "Salt API" "${SALT_API_USER}"
    fi
    echo "${SALT_API_USER}:${SALT_API_USER_PASS}" | chpasswd
    unset SALT_API_USER_PASS
  fi

  log_info "Configuring salt-api service ..."

  CERTS_PATH=/etc/pki
  rm -rf "${CERTS_PATH}"/tls/certs/*
  salt-call --local tls.create_self_signed_cert cacert_path="${CERTS_PATH}" CN="${SALT_API_CERT_CN}"
  chown "${SALT_USER}": "${CERTS_PATH}/tls/certs/${SALT_API_CERT_CN}".{crt,key}

  cat >> "${SALT_ROOT_DIR}/master" <<EOF


#####        salt-api settings       #####
##########################################
# Basic configuration for salt-api
api_logfile: ${SALT_LOGS_DIR}/salt/api.log

rest_cherrypy:
  port: 8000
  ssl_crt: ${CERTS_PATH}/tls/certs/${SALT_API_CERT_CN}.crt
  ssl_key: ${CERTS_PATH}/tls/certs/${SALT_API_CERT_CN}.key
EOF

  # configure supervisord to start salt-api
  cat > /etc/supervisor/conf.d/salt-api.conf <<EOF
[program:salt-api]
priority=10
directory=${SALT_HOME}
environment=HOME=${SALT_HOME}
command=/usr/bin/salt-api
user=${SALT_USER}
autostart=true
autorestart=true
stopsignal=TERM
stdout_logfile=/dev/null
stdout_logfile_maxbytes=0
stderr_logfile=/dev/null
stderr_logfile_maxbytes=0
EOF

}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  configure_salt_formulas
#   DESCRIPTION:  Configure salt-formulas.
#----------------------------------------------------------------------------------------------------------------------
function configure_salt_formulas()
{
  log_info "Configuring 3rd-party salt-formulas ..."
  local master_yml_id="${SELF_MANAGED_BLOCK_STRING} - file_roots-base"
  local begin_delim="${master_yml_id} - begin"
  local end_delim="${master_yml_id} - end"

  tmp_file="$(mktemp /tmp/file_roots-base.XXXXXX)"
  {
    while IFS= read -r -d '' directory
    do
      echo "    - ${directory}"
    done < <(find "${SALT_FORMULAS_DIR}/" -mindepth 1 -maxdepth 1 -type d -print0)
  } > "${tmp_file}"

  sed -i "/${begin_delim}/,/${end_delim}/!b;//!d;/${begin_delim}/r ${tmp_file}" "${SALT_ROOT_DIR}/master"
  rm "${tmp_file}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  initialize_datadir
#   DESCRIPTION:  Initialize main directories.
#----------------------------------------------------------------------------------------------------------------------
function initialize_datadir()
{
  log_info "Configuring directories ..."

  # This symlink simplifies paths for loading sls files
  [[ -d /srv ]] && [[ ! -L /srv ]] && rm -rf /srv
  ln -sfnv "${SALT_BASE_DIR}" /srv
  if [[ -w "${SALT_BASE_DIR}" ]]; then
    chown -R "${SALT_USER}": "${SALT_BASE_DIR}" || log_error "Unable to change '${SALT_BASE_DIR}' ownership"
  else
    log_info "${SALT_BASE_DIR} is mounted as a read-only volume. Ownership won't be changed."
  fi

  # Salt configuration directory
  if [[ -w "${SALT_CONFS_DIR}" ]]; then
    chown -R "${SALT_USER}": "${SALT_CONFS_DIR}" || log_error "Unable to change '${SALT_CONFS_DIR}' ownership"
  else
    log_info "${SALT_CONFS_DIR} is mounted as a read-only volume. Ownership won't be changed."
  fi

  # Set Salt root permissions
  chown -R "${SALT_USER}": "${SALT_ROOT_DIR}"

  # Set Salt run permissions
  mkdir -p /var/run/salt
  chown -R "${SALT_USER}": /var/run/salt

  # Set cache permissions
  mkdir -p /var/cache/salt/master
  chown -R "${SALT_USER}": /var/cache/salt

  # Keys directories
  if [[ ! -w "${SALT_KEYS_DIR}" ]]; then
    log_error "Keys directory: '${SALT_KEYS_DIR}' must be mounted as a read-write volume"
    exit 1
  fi
  mkdir -p "${SALT_KEYS_DIR}/minions"
  chown -R "${SALT_USER}": "${SALT_KEYS_DIR}"

  # Logs directory
  if [[ ! -w "${SALT_LOGS_DIR}" ]]; then
    log_error "Logs directory: '${SALT_LOGS_DIR}' must be mounted as a read-write volume"
    exit 1
  fi
  mkdir -p "${SALT_LOGS_DIR}/salt" "${SALT_LOGS_DIR}/supervisor"
  chmod -R 0755 "${SALT_LOGS_DIR}/supervisor"
  chown -R root: "${SALT_LOGS_DIR}/supervisor"

  # Salt formulas
  if [[ -w "${SALT_FORMULAS_DIR}" ]]; then
    chown -R "${SALT_USER}": "${SALT_FORMULAS_DIR}" || log_error "Unable to change '${SALT_FORMULAS_DIR}' ownership"
  else
    log_info "${SALT_FORMULAS_DIR} is mounted as a read-only volume. Ownership won't be changed."
  fi

  [[ -d /var/log/salt ]] && [[ ! -L /var/log/salt ]] && rm -rf /var/log/salt
  mkdir -p "${SALT_LOGS_DIR}/salt" /var/log
  ln -sfnv "${SALT_LOGS_DIR}/salt" /var/log/salt
  chown -R "${SALT_USER}": "${SALT_LOGS_DIR}/salt"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  configure_logrotate
#   DESCRIPTION:  Configure logrotate.
#----------------------------------------------------------------------------------------------------------------------
function configure_logrotate()
{
  log_info "Configuring logrotate ..."

  rm -f /etc/logrotate.d/salt-common

  # configure supervisord log rotation
  cat > /etc/logrotate.d/supervisord <<EOF
${SALT_LOGS_DIR}/supervisor/*.log {
  ${SALT_LOG_ROTATE_FREQUENCY}
  missingok
  rotate ${SALT_LOG_ROTATE_RETENTION}
  compress
  delaycompress
  notifempty
  copytruncate
}
EOF

  # configure salt master, minion and key log rotation
  cat > /etc/logrotate.d/salt <<EOF
${SALT_LOGS_DIR}/salt/master.log {
  ${SALT_LOG_ROTATE_FREQUENCY}
  missingok
  rotate ${SALT_LOG_ROTATE_RETENTION}
  compress
  notifempty
}

${SALT_LOGS_DIR}/salt/key.log {
  ${SALT_LOG_ROTATE_FREQUENCY}
  missingok
  rotate ${SALT_LOG_ROTATE_RETENTION}
  compress
  notifempty
}
EOF

  if [[ "${SALT_API_SERVICE_ENABLED,,}" == true ]]; then
    # configure salt-api log rotation
    cat >> /etc/logrotate.d/salt <<EOF

${SALT_LOGS_DIR}/salt/api.log {
  ${SALT_LOG_ROTATE_FREQUENCY}
  missingok
  rotate ${SALT_LOG_ROTATE_RETENTION}
  compress
  notifempty
}
EOF
  fi

}

function configure_config_reloader()
{
  rm -f /etc/supervisor/conf.d/config-reloader.conf
  [[ "${SALT_RESTART_MASTER_ON_CONFIG_CHANGE,,}" == true ]] || return 0

  log_info "Configuring config reloader ..."

  # configure supervisord to start config-reloader
  cat > /etc/supervisor/conf.d/config-reloader.conf <<EOF
[program:config-reloader]
priority=20
directory=/tmp
command=/usr/local/sbin/config-reloader
user=root
autostart=true
autorestart=true
stdout_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
stderr_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
EOF
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  initialize_system
#   DESCRIPTION:  Initialize the system.
#----------------------------------------------------------------------------------------------------------------------
function initialize_system()
{
  map_uidgid
  initialize_datadir
  configure_logrotate
  configure_timezone
  configure_salt_master
  configure_salt_api
  configure_salt_formulas
  configure_config_reloader
  setup_salt_keys
  rm -rf /var/run/supervisor.sock
}
