#!/usr/bin/env bash

set -e

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
  if [ -e "/usr/share/zoneinfo/${TIMEZONE}" ]; then
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
#          NAME:  setup_salt_keys
#   DESCRIPTION:  Repair keys permissions and creates keys if neaded.
#----------------------------------------------------------------------------------------------------------------------
function setup_salt_keys()
{
  log_info "Setting up salt keys ..."
  if [ ! -f "${SALT_KEYS_DIR}/master.pem" ]; then
    log_info "Generating keys ..."
    salt-key --gen-keys master --gen-keys-dir "${SALT_KEYS_DIR}"
  fi

  if [ ! -f "${SALT_KEYS_DIR}/${SALT_MASTER_SIGN_KEY_NAME}.pem" ] && [ "${SALT_MASTER_SIGN_PUBKEY}" == True ]; then
    log_info "Generating signed keys ..."
    salt-key --gen-signature --auto-create --pub "${SALT_KEYS_DIR}/master.pub" --signature-path "${SALT_KEYS_DIR}"
  fi

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
#          NAME:  setup_ssh_keys
#   DESCRIPTION:  Configure ssh keys.
#----------------------------------------------------------------------------------------------------------------------
function setup_ssh_keys()
{
  log_info "Configuring ssh ..."

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
api_logfile: ${SALT_LOGS_DIR}/salt/api

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
command=/usr/local/bin/salt-api
user=root
autostart=true
autorestart=true
stopsignal=QUIT
stdout_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
stderr_logfile=${SALT_LOGS_DIR}/supervisor/%(program_name)s.log
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
${SALT_LOGS_DIR}/salt/master {
  ${SALT_LOG_ROTATE_FREQUENCY}
  missingok
  rotate ${SALT_LOG_ROTATE_RETENTION}
  compress
  notifempty
}

${SALT_LOGS_DIR}/salt/minion {
  ${SALT_LOG_ROTATE_FREQUENCY}
  missingok
  rotate ${SALT_LOG_ROTATE_RETENTION}
  compress
  notifempty
}

${SALT_LOGS_DIR}/salt/key {
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

${SALT_LOGS_DIR}/salt/api {
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
  [ "${SALT_RESTART_MASTER_ON_CONFIG_CHANGE,,}" == true ] || return 0

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
  setup_ssh_keys
  rm -rf /var/run/supervisor.sock
}
