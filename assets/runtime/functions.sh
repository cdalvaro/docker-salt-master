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
  local output_dir="$1"

  if [[ ! -f "${SALT_KEYS_DIR}/master.pub" ]]; then
    log_error "Unable to create signed keys without public key: '${SALT_KEYS_DIR}/master.pub'"
    return 1
  fi

  local generated_keys_dir=$(exec_as_salt mktemp -d -t "master_sign.XXXXX")
  [[ -n "${output_dir}" ]] || output_dir="${SALT_KEYS_DIR}/generated/$(basename "${generated_keys_dir}")"

  # This is a really ugly fix realted with issue #226
  #
  ## master's config file changing the keys directory by a temporary directory
  ## This avoid and issue writing the signed keys in the keys directory
  ## when this directory is mounted from the host.
  cp "${SALT_ROOT_DIR}/master" "${generated_keys_dir}/"
  sed -i "s#${SALT_KEYS_DIR}#${generated_keys_dir}#" "${generated_keys_dir}/master"

  # Create keys
  salt-key --gen-signature --auto-create --user "${SALT_USER}" \
        --config-dir "${generated_keys_dir}" \
        --pub "${SALT_KEYS_DIR}/master.pub" \
        --signature-path "${generated_keys_dir}" > /dev/null 2>&1

  # Move keys
  exec_as_salt mkdir -p "${output_dir}"
  mv "${generated_keys_dir}/master_sign".{pem,pub} "${output_dir}/"
  mv "${generated_keys_dir}/master_pubkey_signature" "${output_dir}/"

  # Cleanup
  rm -rf "${generated_keys_dir}"

  echo -n "${output_dir}"
}


#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  _check_key_pair_exists
#   DESCRIPTION:  Check whether the given key-pair files exist.
#     ARGUMENTS:
#           - 1: The path to the key-pair file
#
#----------------------------------------------------------------------------------------------------------------------
function _check_key_pair_exists()
{
  local key_pair_file="$1"
  if [[ ! -f "${key_pair_file}.pem" || ! -f "${key_pair_file}.pub" ]]; then
    [[ -f "${key_pair_file}.pem" ]] || log_error "'${key_pair_file}.pem' doesn't exist"
    [[ -f "${key_pair_file}.pub" ]] || log_error "'${key_pair_file}.pub' doesn't exist"
    return 1
  fi
  return 0
}


#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  _symlink_key_pair_files
#   DESCRIPTION:  Create symlinks for the given key-pair files.
#     ARGUMENTS:
#           - 1: The source key-pair file
#           - 2: The target key-pair file
#
#----------------------------------------------------------------------------------------------------------------------
function _symlink_key_pair_files()
{
  local source_key_pair="$1"
  local target_key_pair="$2"

  ln -sfn "${source_key_pair}.pem" "${target_key_pair}.pem"
  ln -sfn "${source_key_pair}.pub" "${target_key_pair}.pub"
}


#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  setup_keys_for_service
#   DESCRIPTION:  Setup keys for the given service.
#                 If a key-pair is provided via env variable, it will be used.
#                 Otherwise, it will be generated.
#     ARGUMENTS:
#           - 1: The service name: master, minion
#           - 2: The env variable name with the key-pair file path: SALT_MASTER_KEY_FILE, SALT_MINION_KEY_FILE
#           - 3: The keys directory: SALT_KEYS_DIR, SALT_MINION_KEYS_DIR
#
#----------------------------------------------------------------------------------------------------------------------
function setup_keys_for_service()
{
  local service="$1"
  local key_file_env_var="$2"
  local keys_dir="$3"

  log_info " ==> Setting up salt-${service} keys ..."

  local key_pair_file="${!key_file_env_var}"
  if [[ -n "${key_pair_file}" ]]; then
    # shellcheck disable=SC2310
    _check_key_pair_exists "${key_pair_file}" || return 1
  fi

  exec_as_salt mkdir -p "${keys_dir}"

  if [[ ! -f "${keys_dir}/${service}.pem" ]]; then
    if [[ -n "${key_pair_file}" ]]; then
      # Link service keys provided via external files
      local target_key_pair="${keys_dir}/${service}"
      log_info "     Linking '${key_pair_file}' keys to '${target_key_pair}.{pem,pub}' ..."
      _symlink_key_pair_files "${key_pair_file}" "${target_key_pair}"
    else
      log_info "     Creating new keys ..."
      # Fix issue #226
      local tmp_keys_dir="$(exec_as_salt mktemp -d)"
      salt-key --gen-keys "${service}" --gen-keys-dir "${tmp_keys_dir}" --user "${SALT_USER}" > /dev/null 2>&1
      mv "${tmp_keys_dir}"/"${service}".{pem,pub} "${keys_dir}/"
      rm -rf "${tmp_keys_dir}"
    fi
  else
    log_info "     Using existing keys ..."
    if [[ -n "${key_pair_file}" ]]; then
      # If a key is provided via key_pair_file, check whether it is the same as the one in the keys directory
      if ! cmp -s "${key_pair_file}.pem" "${keys_dir}/${service}.pem" ||
         ! cmp -s "${key_pair_file}.pub" "${keys_dir}/${service}.pub"; then
        log_error "     ${key_file_env_var} is set to '${key_pair_file}' but keys don't match the ${service} keys inside '${keys_dir}'."
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
    # shellcheck disable=SC2310
    _check_key_pair_exists "${SALT_MASTER_SIGN_KEY_FILE}" || return 1
  fi

  if [[ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pem" ]]; then
    if [[ -n "${SALT_MASTER_SIGN_KEY_FILE}" ]]; then
      # Link master_sign keys provided via external files
      local target_key_pair="${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}"
      log_info "     Linking '${SALT_MASTER_SIGN_KEY_FILE}' keys to '${target_key_pair}.{pem,pub}' ..."
      _symlink_key_pair_files "${SALT_MASTER_SIGN_KEY_FILE}" "${target_key_pair}"
    else
      log_info "     Generating signed keys ..."
      gen_signed_keys "${SALT_KEYS_DIR}" > /dev/null
    fi
  else
    if [[ -n "${SALT_MASTER_SIGN_KEY_FILE}" ]]; then
      # If a master_sign key-pair is provided via SALT_MASTER_SIGN_KEY_FILE, check it is the same as the one in the keys directory
      if ! cmp -s "${SALT_MASTER_SIGN_KEY_FILE}.pem" "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pem" ||
         ! cmp -s "${SALT_MASTER_SIGN_KEY_FILE}.pub" "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pub"; then
        log_error "     SALT_MASTER_SIGN_KEY_FILE is set to '${SALT_MASTER_SIGN_KEY_FILE}' but keys don't match the master_sign keys inside '${SALT_KEYS_DIR}'."
        return 1
      fi
    fi
  fi

  if [[ -n "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" ]]; then
    if [[ ! -f "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" ]]; then
      log_error "     SALT_MASTER_PUBKEY_SIGNATURE_FILE is set to '${SALT_MASTER_PUBKEY_SIGNATURE_FILE}' but it doesn't exist."
      return 1
    fi

    if [[ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}" ]]; then
      log_info "     Linking '${SALT_MASTER_PUBKEY_SIGNATURE_FILE}' to '${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}' ..."
      ln -sfn "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" "${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}"
    else
      # If a master_pubkey_signature is provided via SALT_MASTER_PUBKEY_SIGNATURE_FILE, check it is the same as the one in the keys directory
      if ! cmp -s "${SALT_MASTER_PUBKEY_SIGNATURE_FILE}" "${SALT_KEYS_DIR}/${SALT_MASTER_PUBKEY_SIGNATURE}"; then
        log_error "     SALT_MASTER_PUBKEY_SIGNATURE_FILE is set to '${SALT_MASTER_PUBKEY_SIGNATURE_FILE}' but it doesn't match the ${SALT_MASTER_PUBKEY_SIGNATURE} inside '${SALT_KEYS_DIR}'."
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
    log_info "     Could not find GPG keys. GPG setup skipped."
    return 0
  fi

  if [[ ! -f "${private_key}" || ! -f "${public_key}" ]]; then
    log_error "     GPG keys are not valid. Please, check the documentation for more information:"
    log_error "      - https://github.com/cdalvaro/docker-salt-master#gpg-keys-for-renderers"
    [[ -f "${private_key}" ]] || log_error "GPG private key: '${private_key##*/}' doesn't exist"
    [[ -f "${public_key}" ]] || log_error "GPG public key: '${public_key##*/}' doesn't exist"
    return 1
  fi

  log_info "     Importing GPG keys ..."

  local SALT_GPGKEYS_DIR="${SALT_ROOT_DIR}"/gpgkeys
  mkdir -p "${SALT_GPGKEYS_DIR}"
  chown "${SALT_USER}:${SALT_USER}" "${SALT_GPGKEYS_DIR}"
  chmod 700 "${SALT_GPGKEYS_DIR}"

  local GPG_COMMON_OPTS=(--no-tty --homedir="${SALT_GPGKEYS_DIR}")

  exec_as_salt gpg "${GPG_COMMON_OPTS[@]}" --import "${private_key}"
  exec_as_salt gpg "${GPG_COMMON_OPTS[@]}" --import "${public_key}"

  log_info "     Setting trust level to ultimate ..."
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
  setup_keys_for_service master SALT_MASTER_KEY_FILE "${SALT_KEYS_DIR}"
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

  if [[ -n "${SALT_API_SERVICE_ENABLED}" ]]; then
    log_warn "SALT_API_SERVICE_ENABLED is deprecated and it will be removed starting from version 3007.2. Use SALT_API_ENABLED instead."
    export SALT_API_ENABLED="${SALT_API_SERVICE_ENABLED}"
  fi

  [[ ${SALT_API_ENABLED,,} == true ]] || return 0

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
#          NAME:  configure_salt_minion
#   DESCRIPTION:  Configure salt-minion if service is set to be enabled.
#----------------------------------------------------------------------------------------------------------------------
function configure_salt_minion()
{
  rm -f /etc/supervisor/conf.d/salt-minion.conf
  [[ ${SALT_MINION_ENABLED,,} == true ]] || return 0

  log_info "Configuring salt-minion service ..."

  # Get master's fingerprint
  log_info " ==> Getting master's fingerprint ..."
  SALT_MASTER_FINGERPRINT="$(salt-key -f master.pub | grep -Ei 'master.pub: ([^\s]+)' | awk '{print $2}')"

  # Update main configuration
  exec_as_salt cp -p "${SALT_RUNTIME_DIR}/config/minion.yml" "${SALT_ROOT_DIR}/minion"

  update_template "${SALT_ROOT_DIR}/minion" \
    SALT_MINION_ID \
    SALT_LOG_LEVEL \
    SALT_LEVEL_LOGFILE \
    SALT_LOGS_DIR \
    SALT_CACHE_DIR \
    SALT_MINION_CONFS_DIR \
    SALT_MINION_KEYS_DIR \
    SALT_USER \
    SALT_MASTER_FINGERPRINT \
    SALT_MASTER_SIGN_PUBKEY

  # Setup keys
  setup_keys_for_service minion SALT_MINION_KEY_FILE "${SALT_MINION_KEYS_DIR}"

  if [[ "${SALT_MASTER_SIGN_PUBKEY}" == True ]]; then
    # Copy master_sign.pub into the pki minion directory
    log_info " ==> Copying master_sign.pub ..."
    if [[ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pub" ]]; then
      log_error "SALT_MASTER_SIGN_PUBKEY is enabled but ${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pub is not found."
      return 1
    fi
    cp -fp "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pub" "${SALT_MINION_KEYS_DIR}/master_sign.pub"
    chown "${SALT_USER}": "${SALT_MINION_KEYS_DIR}/master_sign.pub"
  else
    [[ -f "${SALT_MINION_KEYS_DIR}/master_sign.pub" ]] && rm -f "${SALT_MINION_KEYS_DIR}/master_sign.pub"
  fi

  # Preaccept minion's keys
  log_info " ==> Preaccepting minion's keys ..."
  cp -fp "${SALT_MINION_KEYS_DIR}/minion.pub" "${SALT_KEYS_DIR}/minions/${SALT_MINION_ID}"
  chown "${SALT_USER}": "${SALT_KEYS_DIR}/minions/${SALT_MINION_ID}"

  # Configure supervisord to start salt-minion
  log_info " ==> Configuring supervisord to start salt-minion ..."
  cat > /etc/supervisor/conf.d/salt-minion.conf <<EOF
[program:salt-minion]
priority=20
directory=${SALT_HOME}
environment=HOME=${SALT_HOME}
command=/usr/bin/salt-minion
user=root
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
  chown -R "${SALT_USER}": "${SALT_LOGS_DIR}/supervisor"

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
  local LOGROTATE_CONFIG_DIR='/etc/logrotate.d/salt'
  local LOGROTATE_CONFIG_FILE="${LOGROTATE_CONFIG_DIR}/salt-common.logrotate"

  rm -rf "${LOGROTATE_CONFIG_DIR}"
  mkdir -p "${LOGROTATE_CONFIG_DIR}"

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

  # configure salt logs rotation
  cat > "${LOGROTATE_CONFIG_FILE}" <<EOF
${SALT_LOGS_DIR}/salt/*.log {
  ${SALT_LOG_ROTATE_FREQUENCY}
  missingok
  rotate ${SALT_LOG_ROTATE_RETENTION}
  compress
  notifempty
  create 0640 ${SALT_USER} ${SALT_USER}
}

EOF

}


#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  configure_config_reloader
#   DESCRIPTION:  Configure config reloader.
#----------------------------------------------------------------------------------------------------------------------
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
#          NAME:  install_python_additional_packages
#   DESCRIPTION:  Install additional python packages.
#----------------------------------------------------------------------------------------------------------------------
function install_python_additional_packages()
{
  if [[ -n "${PYTHON_PACKAGES_FILE}" ]]; then
    log_info "Installing additional python packages from: ${PYTHON_PACKAGES_FILE} ..."

    if [[ ! -f "${PYTHON_PACKAGES_FILE}" ]]; then
      log_error "PYTHON_PACKAGES_FILE is set to '${PYTHON_PACKAGES_FILE}' but it doesn't exist."
      return 1
    fi

    salt-pip install --no-cache-dir -r "${PYTHON_PACKAGES_FILE}"
    local RETURN_CODE=$?
    [[ -z "${PYTHON_PACKAGES}" ]] || log_warn "PYTHON_PACKAGES is set, but it will be ignored because PYTHON_PACKAGES_FILE is set."
    return "${RETURN_CODE}"
  fi

  if [[ -n "${PYTHON_PACKAGES}" ]]; then
    IFS=" " read -ra PYTHON_PACKAGES <<< "${PYTHON_PACKAGES}"
    log_info "Installing additional python packages: ${PYTHON_PACKAGES[@]} ..."
    salt-pip install --no-cache-dir "${PYTHON_PACKAGES[@]}"
    return $?
  fi
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
  setup_salt_keys
  configure_salt_api
  configure_salt_minion
  configure_salt_formulas
  configure_config_reloader
  install_python_additional_packages
  rm -rf /var/run/supervisor.sock

  log_info "System initialized successfully!"
}
