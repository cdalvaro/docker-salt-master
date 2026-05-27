#!/usr/bin/env bash

set -o errexit
set -o pipefail

export DEBUG=${DEBUG:-false}

if [[ "${DEBUG,,}" == true ]]; then
  set -o verbose
  set -o xtrace
fi

#---  ENV VARIABLE  ---------------------------------------------------------------------------------------------------
#          NAME:  IMAGE_NAME
#   DESCRIPTION:  The name and tag of the Docker image. Required.
#----------------------------------------------------------------------------------------------------------------------
export IMAGE_NAME=${IMAGE_NAME?Define the docker-salt-master image for testing}

#---  ENV VARIABLE  ---------------------------------------------------------------------------------------------------
#          NAME:  CONTAINER_NAME
#   DESCRIPTION:  The name of the container. Default: 'salt-master'.
#----------------------------------------------------------------------------------------------------------------------
export CONTAINER_NAME=salt-master

#---  ENV VARIABLE  ---------------------------------------------------------------------------------------------------
#          NAME:  TEST_MINION_ID
#   DESCRIPTION:  The id of the salt-minion for testing. Default: 'test.minion'.
#----------------------------------------------------------------------------------------------------------------------
export TEST_MINION_ID=test.minion

#---  ENV VARIABLE  ---------------------------------------------------------------------------------------------------
#          NAME:  PLATFORM
#   DESCRIPTION:  The platform to run the tests on. Default: the current platform.
#----------------------------------------------------------------------------------------------------------------------
export PLATFORM=${PLATFORM:-$(docker version --format='{{.Server.Os}}/{{.Server.Arch}}')}

#---  ENV VARIABLE  ---------------------------------------------------------------------------------------------------
#          NAME:  BOOTUP_WAIT_SECONDS
#   DESCRIPTION:  The number of seconds to wait for the container to boot up. Default: 60.
#----------------------------------------------------------------------------------------------------------------------
export BOOTUP_WAIT_SECONDS=${BOOTUP_WAIT_SECONDS:-60}

#---  ENV VARIABLE  ---------------------------------------------------------------------------------------------------
#          NAME:  LOGS_DIR
#   DESCRIPTION:  The directory to store the logs. Default: 'logs'.
#----------------------------------------------------------------------------------------------------------------------
export LOGS_DIR="${SCRIPT_PATH:-$(mktemp salt_master_test.XXXXX)}/logs"

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  cleanup
#   DESCRIPTION:  Clean up tasks.
#----------------------------------------------------------------------------------------------------------------------
function cleanup() {
  echo "🧹 Running cleanup tasks ..."

  local salt_master_container=
  salt_master_container="$(docker container ls -a --filter NAME="${CONTAINER_NAME}" --quiet)"
  if [[ -n "${salt_master_container}" ]]; then
    echo "  - Removing ${CONTAINER_NAME} docker container ..."
    docker container rm --force --volumes "${salt_master_container}" >/dev/null
    sleep 5
  fi

  if [[ -f "${SCRIPT_PATH:?}/salt-minion.pid" ]]; then
    MINION_PID=$(cat "${SCRIPT_PATH}/salt-minion.pid")
    echo "  - Stopping salt-minion (${MINION_PID}) ..."
    sudo kill "${MINION_PID}" || true

    local timeout_seconds=30
    local elapsed_seconds=0
    while sudo kill -0 "${MINION_PID}" >/dev/null 2>&1; do
      if [[ ${elapsed_seconds} -ge ${timeout_seconds} ]]; then
        echo "  - salt-minion (${MINION_PID}) did not stop after ${timeout_seconds}s. Sending SIGKILL ..."
        sudo kill -9 "${MINION_PID}" || true
        break
      fi
      sleep 1
      ((elapsed_seconds += 1))
    done

    rm -f "${SCRIPT_PATH}/salt-minion.pid"
  fi

  echo "  - Removing logs ..."
  if [[ -d "${LOGS_DIR}" ]]; then
    for service in master minion api key; do
      [[ -f "${LOGS_DIR}/salt/${service}" ]] && rm -fv "${LOGS_DIR}/salt/${service}"
    done
  fi
  [[ -f /var/log/salt/minion ]] && sudo rm -fv /var/log/salt/minion

  echo "🧹 All cleanup tasks done!"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  docker-exec
#   DESCRIPTION:  Execute the given command inside the container.
#     ARGUMENTS:  $@ -> The command to execute with extra arguments if needed.
#----------------------------------------------------------------------------------------------------------------------
function docker-exec() {
  docker exec "${CONTAINER_NAME}" "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  docker-exec-as-salt
#   DESCRIPTION:  Execute the given command inside the container as the `salt` user.
#     ARGUMENTS:  $@ -> The command to execute with extra arguments if needed.
#----------------------------------------------------------------------------------------------------------------------
function docker-exec-as-salt() {
  docker exec --user salt "${CONTAINER_NAME}" "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  docker-logs
#   DESCRIPTION:  Get the logs of the container.
#----------------------------------------------------------------------------------------------------------------------
function docker-logs() {
  docker logs "${CONTAINER_NAME}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  salt-run
#   DESCRIPTION:  Execute the salt-run command inside the container.
#     ARGUMENTS:  $@ -> Extra arguments for the command.
#----------------------------------------------------------------------------------------------------------------------
function salt-run() {
  docker-exec-as-salt salt-run "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  salt-call
#   DESCRIPTION:  Execute the salt-call command inside the container.
#     ARGUMENTS:  $@ -> Extra arguments for the command.
#----------------------------------------------------------------------------------------------------------------------
function salt-call() {
  docker-exec-as-salt salt-call "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  salt
#   DESCRIPTION:  Execute the salt command inside the container.
#     ARGUMENTS:  $@ -> Extra arguments for the command.
#----------------------------------------------------------------------------------------------------------------------
function salt() {
  docker-exec-as-salt salt "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  wait_for_minion
#   DESCRIPTION:  Wait until the given minion starts responding to Salt commands.
#     ARGUMENTS:  $1 -> Minion id. $2 -> Timeout in seconds (default: 40).
#----------------------------------------------------------------------------------------------------------------------
function wait_for_minion() {
  local minion_id="$1"
  local timeout_seconds="${2:-40}"
  local elapsed_seconds=0

  echo "==> Waiting for minion '${minion_id}' to respond ..."
  while [[ ${elapsed_seconds} -lt ${timeout_seconds} ]]; do
    if salt --out=json "${minion_id}" test.ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    ((elapsed_seconds += 2))
  done

  return 1
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  container_log
#   DESCRIPTION:  Print container log.
#----------------------------------------------------------------------------------------------------------------------
function container_log() {
  local CONTAINER_ID=
  CONTAINER_ID="$(docker container ls --all --filter NAME="${CONTAINER_NAME}" --quiet)"
  [[ -n "${CONTAINER_ID}" ]] || return 0

  echo "📝 container log (${CONTAINER_NAME})"
  docker logs -t "${CONTAINER_ID}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  master_log
#   DESCRIPTION:  Print salt-master log.
#----------------------------------------------------------------------------------------------------------------------
function master_log() {
  local SALT_MASTER_LOG="${LOGS_DIR}/salt/master"

  [[ -f "${SALT_MASTER_LOG}" ]] || return 0
  echo "📝 salt-master log (${SALT_MASTER_LOG})"
  sudo cat "${SALT_MASTER_LOG}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  builtin_minion_log
#   DESCRIPTION:  Print built-in salt-minion log.
#----------------------------------------------------------------------------------------------------------------------
function builtin_minion_log() {
  local SALT_MINION_LOG="${LOGS_DIR}/salt/minion"

  [[ -f "${SALT_MINION_LOG}" ]] || return 0
  echo "📝 built-in salt-minion log (${SALT_MINION_LOG})"
  sudo cat "${SALT_MINION_LOG}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  minion_log
#   DESCRIPTION:  Print salt-minion log.
#----------------------------------------------------------------------------------------------------------------------
function minion_log() {
  local SALT_MINION_LOG='/var/log/salt/minion'

  [[ -f "${SALT_MINION_LOG}" ]] || return 0
  echo "📝 salt-minion log (${SALT_MINION_LOG})"
  sudo cat "${SALT_MINION_LOG}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  assert_log_contains / assert_log_not_contains
#   DESCRIPTION:  Assert the container log does (not) contain the given string.
#     ARGUMENTS:  $1 -> Substring. $2 -> Assertion message.
#----------------------------------------------------------------------------------------------------------------------
# NOTE: capture the log into a variable and grep a here-string instead of
# `docker-logs | grep -qF`. Under `set -o pipefail`, `grep -q` exits on the
# first match and closes the pipe, so `docker logs` is killed by SIGPIPE
# (exit 141) and the pipeline reports failure even though the needle WAS
# found — which made assert_log_contains always fail and
# assert_log_not_contains always pass (masking real regressions).
function assert_log_contains() {
  local needle="$1"
  local message="$2"
  local logs
  logs="$(docker-logs 2>&1 || true)"
  if grep -qF -- "${needle}" <<<"${logs}"; then
    ok "${message}"
  else
    error "${message} (expected log to contain: '${needle}')"
  fi
}

function assert_log_not_contains() {
  local needle="$1"
  local message="$2"
  local logs
  logs="$(docker-logs 2>&1 || true)"
  if grep -qF -- "${needle}" <<<"${logs}"; then
    error "${message} (unexpected log entry: '${needle}')"
  else
    ok "${message}"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  wait_container
#   DESCRIPTION:  Wait for the container to boot up.
#     ARGUMENTS:  $@ -> Extra arguments for the docker run command.
#----------------------------------------------------------------------------------------------------------------------
function start_container_and_wait() {
  # shellcheck disable=SC2206
  local DOCKER_ARGS=($@)

  mkdir -p "${LOGS_DIR}"

  # Common config
  mkdir -p "${SCRIPT_PATH}/config/autosign_grains"
  cat >"${SCRIPT_PATH}"/config/autosign_grains.conf <<EOF
autosign_grains_dir: /home/salt/data/config/autosign_grains
EOF
  cat >"${SCRIPT_PATH}"/config/autosign_grains/id <<EOF
${TEST_MINION_ID}
EOF

  docker run --detach --name "${CONTAINER_NAME}" \
    --publish 4505:4505 --publish 4506:4506 \
    --env PUID="$(id -u)" --env PGID="$(id -g)" \
    --env SALT_LOG_LEVEL='info' \
    --platform "${PLATFORM}" "${DOCKER_ARGS[@]}" \
    --volume "${LOGS_DIR}":/home/salt/data/logs \
    --volume "${SCRIPT_PATH}/config":/home/salt/data/config:ro \
    "${IMAGE_NAME}" || return 1

  echo "==> Waiting ${BOOTUP_WAIT_SECONDS} seconds for the container to be ready ..."
  sleep "${BOOTUP_WAIT_SECONDS}"
  # Returns 0 for containers still running or successfully exited
  return "$(docker inspect ${CONTAINER_NAME} --format="{{.State.ExitCode}}")"

}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  setup_and_start_salt_minion
#   DESCRIPTION:  Setup and start salt-minion.
#----------------------------------------------------------------------------------------------------------------------
function setup_and_start_salt_minion() {
  local SALT_MINION_CONF_DIR=/etc/salt/minion.d

  sudo rm -rf '/etc/salt'
  sudo mkdir -p "${SALT_MINION_CONF_DIR}"

  sudo tee "${SALT_MINION_CONF_DIR}/minion.conf" >/dev/null <<EOF
id: ${TEST_MINION_ID}
master: localhost
verify_master_pubkey_sign: False
master_alive_interval: 10
retry_dns: 5
retry_dns_count: 4
autosign_grains:
  - uuid
  - id
EOF

  echo "==> Starting salt-minion ..."
  sudo salt-minion --log-file-level=info --daemon --pid-file "${SCRIPT_PATH}/salt-minion.pid" &
  sleep 40

  test -n "$(pgrep -f salt-minion)"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  ok
#   DESCRIPTION:  Print a success message.
#----------------------------------------------------------------------------------------------------------------------
function ok() {
  echo "✅ $*"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  error
#   DESCRIPTION:  Print an error message, show the salt-master log and exit with code 1.
#----------------------------------------------------------------------------------------------------------------------
function error() {
  echo "🔥 $*" >&2
  container_log >&2
  master_log >&2
  builtin_minion_log >&2
  minion_log >&2
  return 1
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_equal
#   DESCRIPTION:  Check if the given value is equal to the expected value.
#     ARGUMENTS:
#                 $1 -> The actual value.
#                 $2 -> The expected value.
#                 $3 -> The message to show.
#----------------------------------------------------------------------------------------------------------------------
function check_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  output=$(
    cat <<EOF
${message}
  Expected: ${expected}
    Actual: ${actual}
EOF
  )

  if [[ "${actual}" == "${expected}" ]]; then
    ok "${output}"
  else
    error "${output}"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  variable_is_empty
#   DESCRIPTION:  Check whether the given variable is empty.
#     ARGUMENTS:
#                 $1 -> The cotent to check.
#                 $2 -> The message to show.
#----------------------------------------------------------------------------------------------------------------------
function is_empty() {
  local variable="$1"
  local message="$2"

  if [[ -z "${variable}" ]]; then
    ok "${message}"
  else
    error "${message}"
  fi
}
