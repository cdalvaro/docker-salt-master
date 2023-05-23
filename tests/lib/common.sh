#!/usr/bin/env bash

set -o errexit
set -o pipefail

if [[ "${DEBUG,,}" == true ]]; then
  set -o verbose
  set -o xtrace
fi

#---  ENV VARIABLE  ---------------------------------------------------------------------------------------------------
#          NAME:  IMAGE_NAME
#   DESCRIPTION:  The name and tag of the Docker image. Default: 'cdalvaro/docker-salt-master:latest'.
#----------------------------------------------------------------------------------------------------------------------
export IMAGE_NAME=${IMAGE_NAME:-'cdalvaro/docker-salt-master:latest'}

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

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  cleanup
#   DESCRIPTION:  Clean up tasks.
#----------------------------------------------------------------------------------------------------------------------
function cleanup()
{
  echo "🧹 Running cleanup tasks ..."

  local salt_master_container="$(docker container ls --filter NAME="${CONTAINER_NAME}" --quiet)"
  if [[ -n "${salt_master_container}" ]]; then
    echo "  - Removing ${CONTAINER_NAME} docker container ..."
    docker container rm --force --volumes "${salt_master_container}" > /dev/null
  fi

  local SALT_MINION_PIDS=$(pgrep -f salt-minion)
  if [[ -n "${SALT_MINION_PIDS}" ]]; then
    echo "  - Stopping salt-minion ..."
    sudo kill "${SALT_MINION_PIDS}"
    sudo rm -f /var/log/salt/minion
  fi

  echo "🧹 All cleanup tasks done!"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  docker-exec
#   DESCRIPTION:  Execute the given command inside the container.
#----------------------------------------------------------------------------------------------------------------------
function docker-exec()
{
  docker exec "${CONTAINER_NAME}" "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  docker-logs
#   DESCRIPTION:  Get the logs of the container.
#----------------------------------------------------------------------------------------------------------------------
function docker-logs()
{
  docker logs "${CONTAINER_NAME}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  salt-run
#   DESCRIPTION:  Execute the salt-run command inside the container.
#----------------------------------------------------------------------------------------------------------------------
function salt-run()
{
  docker-exec salt-run "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  salt-call
#   DESCRIPTION:  Execute the salt-call command inside the container.
#----------------------------------------------------------------------------------------------------------------------
function salt-call()
{
  docker-exec salt-call "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  salt
#   DESCRIPTION:  Execute the salt command inside the container.
#----------------------------------------------------------------------------------------------------------------------
function salt()
{
  docker-exec salt "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  container_log
#   DESCRIPTION:  Print container log.
#----------------------------------------------------------------------------------------------------------------------
function container_log()
{
  local CONTAINER_ID="$(docker container ls --all --filter NAME="${CONTAINER_NAME}" --quiet)"
  [[ -n "${CONTAINER_ID}" ]] || return 0

  echo "📝 container log (${CONTAINER_NAME})"
  docker logs -t "${CONTAINER_ID}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  master_log
#   DESCRIPTION:  Print salt-master log.
#----------------------------------------------------------------------------------------------------------------------
function master_log()
{
  local LOGS_DIR="${SCRIPT_PATH}/logs"
  local SALT_MASTER_LOG="${LOGS_DIR}/salt/master.log"

  [[ -f "${SALT_MASTER_LOG}" ]] || return 0
  echo "📝 salt-master log (${SALT_MASTER_LOG})"
  sudo cat "${SALT_MASTER_LOG}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  minion_log
#   DESCRIPTION:  Print salt-minion log.
#----------------------------------------------------------------------------------------------------------------------
function minion_log()
{
  local SALT_MINION_LOG='/var/log/salt/minion'

  [[ -f "${SALT_MINION_LOG}" ]] || return 0
  echo "📝 salt-minion log (${SALT_MINION_LOG})"
  sudo cat "${SALT_MINION_LOG}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  wait_container
#   DESCRIPTION:  Wait for the container to boot up.
#----------------------------------------------------------------------------------------------------------------------
function start_container_and_wait()
{
  # shellcheck disable=SC2206
  local DOCKER_ARGS=( $@ )
  local LOGS_DIR="${SCRIPT_PATH}/logs"
  mkdir -p "${LOGS_DIR}"

  # Common config
  mkdir -p "${SCRIPT_PATH}/config/autosign_grains"
  cat > "${SCRIPT_PATH}"/config/autosign_grains.conf <<EOF
autosign_grains_dir: /home/salt/data/config/autosign_grains
EOF
  cat > "${SCRIPT_PATH}"/config/autosign_grains/id <<EOF
${TEST_MINION_ID}
EOF

  docker run --detach --name "${CONTAINER_NAME}" \
  --publish 4505:4505 --publish 4506:4506 \
  --env PUID="$(id -u)" --env PGID="$(id -g)" \
  --env SALT_LOG_LEVEL='info' \
  --platform "${PLATFORM}" ${DOCKER_ARGS[@]} \
  --volume "${LOGS_DIR}":/home/salt/data/logs \
  --volume "${SCRIPT_PATH}/config":/home/salt/data/config:ro \
  "${IMAGE_NAME}" || return 1

  echo "==> Waiting ${BOOTUP_WAIT_SECONDS} seconds for the container to be ready ..."
  sleep "${BOOTUP_WAIT_SECONDS}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  setup_and_start_salt_minion
#   DESCRIPTION:  Setup and start salt-minion.
#----------------------------------------------------------------------------------------------------------------------
function setup_and_start_salt_minion()
{
  local SALT_MINION_CONF_DIR=/etc/salt/minion.d

  sudo rm -rf '/etc/salt'
  sudo mkdir -p "${SALT_MINION_CONF_DIR}"

  sudo tee "${SALT_MINION_CONF_DIR}/minion.conf" > /dev/null <<EOF
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
  sudo salt-minion --log-file-level=info --daemon &
  sleep 40

  test -n "$(pgrep -f salt-minion)"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  ok
#   DESCRIPTION:  Print a success message.
#----------------------------------------------------------------------------------------------------------------------
function ok()
{
  echo "✅ $*"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  error
#   DESCRIPTION:  Print an error message, show the salt-master log and exit with code 1.
#----------------------------------------------------------------------------------------------------------------------
function error()
{
  echo "🔥 $*" >&2
  container_log >&2
  master_log >&2
  minion_log >&2
  return 1
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_equal
#   DESCRIPTION:  Check if the given value is equal to the expected value.
#----------------------------------------------------------------------------------------------------------------------
function check_equal()
{
  local actual="$1"
  local expected="$2"
  local message="$3"

  output=$(cat <<EOF
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
