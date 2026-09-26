#!/usr/bin/env bash

echo "🧪 Running salt-ssh tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
# shellcheck source=tests/lib/common.sh
source "${COMMON_FILE}"

export SSH_NETWORK=salt-ssh-test
export SSH_TARGET_NAME=salt-ssh-target
export SSH_TARGET_IMAGE=salt-ssh-target:test
export SSH_TARGET_PASSWORD=S4lt-SSH-t3st

export SALTAPI_URL="https://localhost:8000/"
export SALTAPI_USER=salt_api
export SALTAPI_PASS=4wesome-Pass0rd
export SALTAPI_EAUTH=pam

KEYS_DIR="${SCRIPT_PATH}/keys"
SALT_SSH_KEY=/home/salt/data/keys/ssh/salt-ssh.rsa
# Defined in roots/pillar/salt_ssh_test.sls
EXPECTED_PILLAR_MESSAGE='Hello from docker-salt-master via salt-ssh'

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  cleanup_salt_ssh
#   DESCRIPTION:  Run common cleanup tasks and remove the salt-ssh target container, image and network.
#----------------------------------------------------------------------------------------------------------------------
function cleanup_salt_ssh() {
  cleanup
  echo "  - Removing salt-ssh target ..."
  docker container rm --force "${SSH_TARGET_NAME}" >/dev/null 2>&1 || true
  docker image rm --force "${SSH_TARGET_IMAGE}" >/dev/null 2>&1 || true
  docker network rm "${SSH_NETWORK}" >/dev/null 2>&1 || true
}
trap cleanup_salt_ssh EXIT

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  salt-ssh
#   DESCRIPTION:  Execute the salt-ssh command inside the container.
#     ARGUMENTS:  $@ -> Extra arguments for the command.
#----------------------------------------------------------------------------------------------------------------------
function salt-ssh() {
  docker-exec-as-salt salt-ssh "$@"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  target-exec
#   DESCRIPTION:  Execute the given command inside the salt-ssh target container.
#     ARGUMENTS:  $@ -> The command to execute with extra arguments if needed.
#----------------------------------------------------------------------------------------------------------------------
function target-exec() {
  docker exec "${SSH_TARGET_NAME}" "$@"
}

# Start from scratch so the salt-ssh key generation is actually tested
rm -rf "${KEYS_DIR}"
mkdir -p "${KEYS_DIR}"

# Start salt-ssh target
echo "==> Building salt-ssh target image (${PLATFORM}) ..."
docker build --platform "${PLATFORM}" --tag "${SSH_TARGET_IMAGE}" "${SCRIPT_PATH}/target" ||
  error "salt-ssh target image built"
ok "salt-ssh target image built"

echo "==> Starting salt-ssh target ..."
docker network create "${SSH_NETWORK}" >/dev/null || error "docker network created"
docker run --detach --name "${SSH_TARGET_NAME}" --hostname "${SSH_TARGET_NAME}" \
  --network "${SSH_NETWORK}" --platform "${PLATFORM}" \
  "${SSH_TARGET_IMAGE}" >/dev/null || error "salt-ssh target started"
printf 'root:%s\nsaltssh:%s\n' "${SSH_TARGET_PASSWORD}" "${SSH_TARGET_PASSWORD}" |
  docker exec --interactive "${SSH_TARGET_NAME}" chpasswd || error "salt-ssh target passwords set"
ok "salt-ssh target started"

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with salt-ssh roster ..."
start_container_and_wait \
  --network "${SSH_NETWORK}" \
  --volume "${SCRIPT_PATH}/roots":/home/salt/data/srv:ro \
  --volume "${SCRIPT_PATH}/roster":/home/salt/data/roster:ro \
  --volume "${SCRIPT_PATH}/roster.d":/home/salt/data/roster.d:ro \
  --volume "${KEYS_DIR}":/home/salt/data/keys ||
  error "container started"
ok "container started"

# Check salt-ssh version
echo "==> Checking salt-ssh version ..."
output="$(docker-exec salt-ssh --version)"
echo "${output}"
CURRENT_VERSION="$(echo -n "${output}" | awk '{print $2}')"
check_equal "${CURRENT_VERSION%%-*}" "${SALT_VERSION%%-*}" "salt-ssh version"

# Check salt-ssh configuration
echo "==> Checking salt-ssh roster configuration ..."
ROSTER_FILE="$(salt-run --out=json config.get roster_file | jq -rM . || error "salt-run config.get roster_file")"
check_equal "${ROSTER_FILE}" "/home/salt/data/roster" "roster_file"
ROSTERS="$(salt-run --out=json config.get rosters | jq -cM . || error "salt-run config.get rosters")"
check_equal "${ROSTERS}" '["/home/salt/data/roster.d"]' "rosters"

# Test key deployment with password authentication
echo "==> Deploying salt-ssh key to ${SSH_TARGET_NAME} (root) ..."
output="$(salt-ssh --out=json --key-deploy --passwd "${SSH_TARGET_PASSWORD}" salt-ssh-root test.ping ||
  error "salt-ssh --key-deploy (root)")"
check_equal "$(jq -rM '."salt-ssh-root"' <<<"${output}")" true "salt-ssh --key-deploy test.ping (root)"

echo "==> Checking salt-ssh key pair ..."
[[ -f "${KEYS_DIR}/ssh/salt-ssh.rsa" && -f "${KEYS_DIR}/ssh/salt-ssh.rsa.pub" ]] ||
  error "salt-ssh key pair generated inside the keys directory"
ok "salt-ssh key pair generated inside the keys directory"
check_equal "$(docker-exec stat -c '%U %a' "${SALT_SSH_KEY}")" "salt 600" "salt-ssh private key owner and mode"

SALT_SSH_PUBKEY="$(cat "${KEYS_DIR}/ssh/salt-ssh.rsa.pub")"
target-exec grep -qF "$(awk '{print $2}' <<<"${SALT_SSH_PUBKEY}")" /root/.ssh/authorized_keys ||
  error "salt-ssh key deployed to root authorized_keys"
ok "salt-ssh key deployed to root authorized_keys"

# Test key authentication
echo "==> Testing salt-ssh test.ping with key authentication (root) ..."
output="$(salt-ssh --out=json salt-ssh-root test.ping || error "salt-ssh test.ping (root)")"
check_equal "$(jq -rM '."salt-ssh-root"' <<<"${output}")" true "salt-ssh test.ping with key authentication (root)"

echo "==> Checking salt-ssh runs on ${SSH_TARGET_NAME} ..."
output="$(salt-ssh --out=json salt-ssh-root grains.get host || error "salt-ssh grains.get host")"
check_equal "$(jq -rM '."salt-ssh-root"' <<<"${output}")" "${SSH_TARGET_NAME}" "salt-ssh grains.get host"

# Test raw shell
echo "==> Testing salt-ssh raw shell ..."
output="$(salt-ssh --out=json --raw-shell salt-ssh-root 'uname -s' || error "salt-ssh raw shell")"
check_equal "$(jq -rM '."salt-ssh-root".stdout' <<<"${output}")" "Linux" "salt-ssh raw shell"

# Test state.apply with pillar data
echo "==> Testing salt-ssh state.apply with pillar data ..."
output="$(salt-ssh --out=json salt-ssh-root state.apply salt_ssh_test || error "salt-ssh state.apply salt_ssh_test")"
echo "${output}"
check_equal "$(jq -rM '."salt-ssh-root" | [.[].result] | all' <<<"${output}")" true "salt-ssh state.apply salt_ssh_test"
check_equal "$(target-exec cat /tmp/salt-ssh-test.txt)" "${EXPECTED_PILLAR_MESSAGE}" "salt-ssh pillar data rendered on ${SSH_TARGET_NAME}"

# Test non-root user with and without sudo
echo "==> Deploying salt-ssh key to ${SSH_TARGET_NAME} (saltssh) ..."
output="$(salt-ssh --out=json --key-deploy --passwd "${SSH_TARGET_PASSWORD}" salt-ssh-user test.ping ||
  error "salt-ssh --key-deploy (saltssh)")"
check_equal "$(jq -rM '."salt-ssh-user"' <<<"${output}")" true "salt-ssh --key-deploy test.ping (saltssh)"

echo "==> Testing salt-ssh without sudo (saltssh) ..."
output="$(salt-ssh --out=json salt-ssh-user cmd.run whoami || error "salt-ssh cmd.run whoami (saltssh)")"
check_equal "$(jq -rM '."salt-ssh-user"' <<<"${output}")" saltssh "salt-ssh runs as saltssh"

echo "==> Testing salt-ssh with sudo (saltssh) ..."
output="$(salt-ssh --out=json salt-ssh-sudo cmd.run whoami || error "salt-ssh cmd.run whoami (saltssh with sudo)")"
check_equal "$(jq -rM '."salt-ssh-sudo"' <<<"${output}")" root "salt-ssh runs as root through sudo"

# Test salt-ssh log file
echo "==> Checking salt-ssh log file ..."
[[ -f "${LOGS_DIR}/salt/ssh" ]] || error "salt-ssh log file"
ok "salt-ssh log file"

# Stop container
echo "==> Stopping previous container ..."
cleanup || error "Unable to stop previous container"

# Create salt-api configuration
echo "==> Creating salt-api configuration file ..."
cat >"${SCRIPT_PATH}/config/salt-api.conf" <<EOF
netapi_enable_clients:
  - ssh

external_auth:
  ${SALTAPI_EAUTH}:
    ${SALTAPI_USER}:
      - .*
EOF
ok "salt-api config created"

# Test salt-ssh key persistence and salt-api ssh client
echo "==> Starting docker-salt-master (${PLATFORM}) with previous salt-ssh keys and salt-api ..."
start_container_and_wait \
  --network "${SSH_NETWORK}" \
  --publish 8000:8000 \
  --env SALT_API_ENABLED=True \
  --env SALT_API_USER_PASS="${SALTAPI_PASS}" \
  --volume "${SCRIPT_PATH}/roots":/home/salt/data/srv:ro \
  --volume "${SCRIPT_PATH}/roster":/home/salt/data/roster:ro \
  --volume "${SCRIPT_PATH}/roster.d":/home/salt/data/roster.d:ro \
  --volume "${KEYS_DIR}":/home/salt/data/keys ||
  error "container started"
ok "container started"

echo "==> Testing salt-ssh test.ping with previous key (root) ..."
output="$(salt-ssh --out=json salt-ssh-root test.ping || error "salt-ssh test.ping with previous key (root)")"
check_equal "$(jq -rM '."salt-ssh-root"' <<<"${output}")" true "salt-ssh test.ping with previous key (root)"
check_equal "$(cat "${KEYS_DIR}/ssh/salt-ssh.rsa.pub")" "${SALT_SSH_PUBKEY}" "salt-ssh key reused after restart"
check_equal "$(docker-exec stat -c '%U %a' "${SALT_SSH_KEY}")" "salt 600" "salt-ssh private key owner and mode after restart"

echo "==> Getting salt-api token ..."
output="$(curl -sSk "${SALTAPI_URL%/}/login" \
  -H "Accept: application/json" \
  -d username="${SALTAPI_USER}" \
  -d password="${SALTAPI_PASS}" \
  -d eauth="${SALTAPI_EAUTH}" || error "salt-api login")"
SALTAPI_TOKEN="$(jq -rM '.return[0].token // empty' <<<"${output}")"
[[ -n "${SALTAPI_TOKEN}" ]] || error "salt-api token"
ok "salt-api token"

echo "==> Testing salt-api ssh client with roster from roster.d ..."
output="$(curl -sSk "${SALTAPI_URL}" \
  -H "Accept: application/json" \
  -H "X-Auth-Token: ${SALTAPI_TOKEN}" \
  -d client=ssh \
  -d tgt=salt-ssh-api \
  -d fun=test.ping \
  -d roster_file=api || error "salt-api ssh client")"
echo "${output}"
# The ssh client may return either the bare value or the full job return
check_equal "$(jq -rM '.return[0]."salt-ssh-api" | if type == "object" then .return else . end' <<<"${output}")" \
  true "salt-api ssh client test.ping using roster.d/api"
