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
export SSH_PYTHON_TARGET_NAME=salt-ssh-python-target
export SSH_PYTHON_TARGET_IMAGE=salt-ssh-python-target:test

export SALTAPI_URL="https://localhost:8000/"
export SALTAPI_USER=salt_api
export SALTAPI_PASS=4wesome-Pass0rd
export SALTAPI_EAUTH=pam

KEYS_DIR="${SCRIPT_PATH}/keys"
CUSTOM_SALT_SSH_DIR=/home/salt/data/custom-salt-ssh
DEFAULT_KNOWN_HOSTS=/home/salt/data/keys/ssh/known_hosts
# UserKnownHostsFile set through ssh_options in config/ssh.conf
SSH_OPTIONS_KNOWN_HOSTS=/tmp/known_hosts
# Network alias of the target that is never added to known_hosts beforehand
SSH_NEW_HOST=salt-ssh-new-host
# Network alias of the target used by the password-only roster entry (not in known_hosts beforehand)
SSH_PASSWORD_HOST=salt-ssh-password-host
# Message returned by salt-ssh when a host is not in known_hosts
UNKNOWN_HOST_ERROR="The host key needs to be accepted"
# Defined in roots/pillar/salt_ssh_test.sls
EXPECTED_PILLAR_MESSAGE='Hello from docker-salt-master via salt-ssh'
# Python version (MAJOR.MINOR) of the target used to test ssh_ext_alternatives
SSH_PYTHON_VERSION=3.10
# Python version installed through SALT_SSH_PYTHON_VERSIONS: a patch version that is not the latest 3.10,
# to check that it is honored
SSH_PYTHON_PATCH_VERSION=3.10.20
SSH_PYTHON_DIR="/opt/salt-ssh/python${SSH_PYTHON_VERSION}"
# salt package of the onedir, packed by ssh_ext_alternatives
SSH_PYTHON_SALT_PATH=/opt/salt-ssh/salt
SSH_PYTHON_NAMESPACE="python${SSH_PYTHON_VERSION}"

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  cleanup_salt_ssh
#   DESCRIPTION:  Run common cleanup tasks and remove the salt-ssh target containers, images and network.
#----------------------------------------------------------------------------------------------------------------------
function cleanup_salt_ssh() {
  cleanup
  echo "  - Removing salt-ssh targets ..."
  docker container rm --force "${SSH_TARGET_NAME}" "${SSH_PYTHON_TARGET_NAME}" >/dev/null 2>&1 || true
  docker image rm --force "${SSH_TARGET_IMAGE}" "${SSH_PYTHON_TARGET_IMAGE}" >/dev/null 2>&1 || true
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

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_salt_ssh_fails
#   DESCRIPTION:  Check that salt-ssh fails and that its output contains the expected message.
#     ARGUMENTS:
#                 $1 -> The expected message.
#                 $2 -> The message to show.
#                 $@ -> Arguments for salt-ssh.
#----------------------------------------------------------------------------------------------------------------------
function check_salt_ssh_fails() {
  local expected="$1"
  local message="$2"
  shift 2

  local output=
  if output="$(salt-ssh --out=json "$@" 2>&1)"; then
    echo "${output}"
    error "${message} (salt-ssh succeeded)"
  fi
  echo "${output}"

  grep -qF -- "${expected}" <<<"${output}" || error "${message} (expected output to contain: '${expected}')"
  ok "${message}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_salt_ssh_python_versions_rejected
#   DESCRIPTION:  Check that the given SALT_SSH_PYTHON_VERSIONS is rejected before installing any Python version.
#                 Only the installation is run, in a new container, so services are not started.
#     ARGUMENTS:
#                 $1 -> The value of SALT_SSH_PYTHON_VERSIONS.
#                 $2 -> The expected error message.
#----------------------------------------------------------------------------------------------------------------------
function check_salt_ssh_python_versions_rejected() {
  local python_versions="$1"
  local expected_error="$2"
  local message="SALT_SSH_PYTHON_VERSIONS='${python_versions}' is rejected before installing any Python version"

  local output=
  # shellcheck disable=SC2016
  output="$(docker run --rm --platform "${PLATFORM}" --env SALT_SSH_PYTHON_VERSIONS="${python_versions}" \
    --entrypoint /bin/bash "${IMAGE_NAME}" \
    -c 'source "${SALT_RUNTIME_DIR}/functions.sh" && install_salt_ssh_python_versions' 2>&1)" &&
    error "${message}"
  echo "${output}"

  if ! grep -qF "${expected_error}" <<<"${output}" || grep -qF "Installing Python" <<<"${output}"; then
    error "${message}"
  fi
  ok "${message}"
}

# Start from scratch so the salt-ssh key generation and host key checking are actually tested
rm -rf "${KEYS_DIR}"
mkdir -p "${KEYS_DIR}"
rm -f "${SCRIPT_PATH}/config/ssh.conf"

# Start salt-ssh target
echo "==> Building salt-ssh target image (${PLATFORM}) ..."
docker build --platform "${PLATFORM}" --tag "${SSH_TARGET_IMAGE}" "${SCRIPT_PATH}/target" ||
  error "salt-ssh target image built"
ok "salt-ssh target image built"

echo "==> Starting salt-ssh target ..."
docker network create "${SSH_NETWORK}" >/dev/null || error "docker network created"
docker run --detach --name "${SSH_TARGET_NAME}" --hostname "${SSH_TARGET_NAME}" \
  --network "${SSH_NETWORK}" --platform "${PLATFORM}" \
  --network-alias "${SSH_NEW_HOST}" --network-alias "${SSH_PASSWORD_HOST}" \
  "${SSH_TARGET_IMAGE}" >/dev/null || error "salt-ssh target started"
printf 'root:%s\n' "${SSH_TARGET_PASSWORD}" |
  docker exec --interactive "${SSH_TARGET_NAME}" chpasswd || error "salt-ssh target password set"
ok "salt-ssh target started"

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with salt-ssh roster ..."
start_container_and_wait \
  --network "${SSH_NETWORK}" \
  --volume "${SCRIPT_PATH}/roots":/home/salt/data/srv:ro \
  --volume "${SCRIPT_PATH}/salt-ssh":/home/salt/data/salt-ssh:ro \
  --volume "${KEYS_DIR}":/home/salt/data/keys ||
  error "container started"
ok "container started"

# Test key deployment with password authentication. The target is not in known_hosts yet,
# so -i is needed to accept and store its host key.
echo "==> Deploying salt-ssh key to ${SSH_TARGET_NAME} ..."
output="$(salt-ssh --out=json -i --key-deploy --passwd "${SSH_TARGET_PASSWORD}" salt-ssh-root test.ping ||
  error "salt-ssh -i --key-deploy")"
check_equal "$(jq -rM '."salt-ssh-root"' <<<"${output}")" true "salt-ssh -i --key-deploy test.ping"
[[ -f "${KEYS_DIR}/ssh/salt-ssh.rsa" ]] || error "salt-ssh key generated inside the keys directory"
ok "salt-ssh key generated inside the keys directory"
docker-exec-as-salt ssh-keygen -F "${SSH_TARGET_NAME}" -f "${DEFAULT_KNOWN_HOSTS}" >/dev/null ||
  error "${SSH_TARGET_NAME} host key stored in ${DEFAULT_KNOWN_HOSTS}"
ok "${SSH_TARGET_NAME} host key stored in ${DEFAULT_KNOWN_HOSTS}"

echo "==> Testing salt-ssh test.ping with key authentication ..."
output="$(salt-ssh --out=json salt-ssh-root test.ping || error "salt-ssh test.ping")"
check_equal "$(jq -rM '."salt-ssh-root"' <<<"${output}")" true "salt-ssh test.ping with key authentication"

# Test state.apply with pillar data
echo "==> Testing salt-ssh state.apply with pillar data ..."
output="$(salt-ssh --out=json salt-ssh-root state.apply salt_ssh_test || error "salt-ssh state.apply salt_ssh_test")"
echo "${output}"
check_equal "$(jq -rM '."salt-ssh-root" | [.[].result] | all' <<<"${output}")" true "salt-ssh state.apply salt_ssh_test"
check_equal "$(target-exec cat /tmp/salt-ssh-test.txt)" "${EXPECTED_PILLAR_MESSAGE}" "salt-ssh pillar data rendered on ${SSH_TARGET_NAME}"

# Test host key checking
echo "==> Testing salt-ssh rejects hosts not in known_hosts ..."
check_salt_ssh_fails "${UNKNOWN_HOST_ERROR}" "salt-ssh rejects ${SSH_NEW_HOST} (not in known_hosts)" \
  "${SSH_NEW_HOST}" test.ping

# Pin a different host key for SSH_NEW_HOST, so it looks like a known host whose key has changed
echo "==> Testing salt-ssh rejects hosts whose key has changed ..."
# shellcheck disable=SC2016
docker-exec-as-salt bash -c 'ssh-keygen -q -t ed25519 -N "" -f /tmp/changed_host_key &&
  echo "$1 $(cut -d " " -f 1,2 /tmp/changed_host_key.pub)" >>"$2"' _ "${SSH_NEW_HOST}" "${DEFAULT_KNOWN_HOSTS}" ||
  error "different host key pinned for ${SSH_NEW_HOST}"
check_salt_ssh_fails "Host key verification failed" "salt-ssh rejects ${SSH_NEW_HOST} (host key changed)" \
  "${SSH_NEW_HOST}" test.ping

# Documented exception: password-only roster entries (priv: null) connect with StrictHostKeyChecking=no,
# so they accept and store the host key of hosts that are not in known_hosts yet, without -i.
echo "==> Testing password-only roster entries accept hosts not in known_hosts ..."
output="$(salt-ssh --out=json --passwd "${SSH_TARGET_PASSWORD}" salt-ssh-password test.ping ||
  error "salt-ssh salt-ssh-password test.ping")"
check_equal "$(jq -rM '."salt-ssh-password"' <<<"${output}")" true "password-only roster entry accepts ${SSH_PASSWORD_HOST}"
docker-exec-as-salt ssh-keygen -F "${SSH_PASSWORD_HOST}" -f "${DEFAULT_KNOWN_HOSTS}" >/dev/null ||
  error "${SSH_PASSWORD_HOST} host key stored in ${DEFAULT_KNOWN_HOSTS}"
ok "${SSH_PASSWORD_HOST} host key stored in ${DEFAULT_KNOWN_HOSTS}"

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

# Use a different known_hosts file through ssh_options
echo "==> Creating ssh configuration file ..."
cat >"${SCRIPT_PATH}/config/ssh.conf" <<EOF
ssh_options:
  - UserKnownHostsFile=${SSH_OPTIONS_KNOWN_HOSTS}
EOF
ok "ssh config created"

# Test custom SALT_SSH_DIR, ssh_options, salt-ssh key persistence and salt-api ssh client
echo "==> Starting docker-salt-master (${PLATFORM}) with custom SALT_SSH_DIR, previous salt-ssh keys and salt-api ..."
start_container_and_wait \
  --network "${SSH_NETWORK}" \
  --publish 8000:8000 \
  --env SALT_API_ENABLED=True \
  --env SALT_API_USER_PASS="${SALTAPI_PASS}" \
  --env SALT_SSH_DIR="${CUSTOM_SALT_SSH_DIR}" \
  --volume "${SCRIPT_PATH}/roots":/home/salt/data/srv:ro \
  --volume "${SCRIPT_PATH}/salt-ssh":"${CUSTOM_SALT_SSH_DIR}":ro \
  --volume "${KEYS_DIR}":/home/salt/data/keys ||
  error "container started"
ok "container started"

# The default known_hosts file (in the keys volume) already has the target from the first container,
# so the target is only rejected if salt-ssh uses the known_hosts file set through ssh_options.
echo "==> Testing salt-ssh uses UserKnownHostsFile from ssh_options ..."
check_salt_ssh_fails "${UNKNOWN_HOST_ERROR}" "salt-ssh uses UserKnownHostsFile from ssh_options" \
  salt-ssh-root test.ping

# The roster is read from the custom SALT_SSH_DIR, and the key from the previous container is reused
# (it is not deployed again). -i is needed because the known_hosts file set through ssh_options is empty.
echo "==> Testing salt-ssh test.ping with the previous key ..."
output="$(salt-ssh --out=json -i salt-ssh-root test.ping || error "salt-ssh test.ping with the previous key")"
check_equal "$(jq -rM '."salt-ssh-root"' <<<"${output}")" true "salt-ssh test.ping with the previous key"

# The earlier X-Auth-Token request returned 401 in this test setup. Use eauth credentials here
# without assuming that every token authentication flow fails with the ssh client.
echo "==> Testing salt-api ssh client with roster from roster.d ..."
output="$(curl -sSk "${SALTAPI_URL%/}/run" \
  -H "Accept: application/json" \
  -d client=ssh \
  -d tgt=salt-ssh-api \
  -d fun=test.ping \
  -d roster_file=api \
  -d username="${SALTAPI_USER}" \
  -d password="${SALTAPI_PASS}" \
  -d eauth="${SALTAPI_EAUTH}" || error "salt-api ssh client")"
echo "${output}"
# The ssh client may return either the bare value or the full job return
check_equal "$(jq -rM '.return[0]."salt-ssh-api" | if type == "object" then .return else . end' <<<"${output}")" \
  true "salt-api ssh client test.ping using roster.d/api"

# Stop container
echo "==> Stopping previous container ..."
cleanup || error "Unable to stop previous container"

# Invalid SALT_SSH_PYTHON_VERSIONS values. Each one comes after a valid version,
# so it also checks that no version is installed before checking all of them.
echo "==> Checking SALT_SSH_PYTHON_VERSIONS validation ..."
# A version on a new line must not be ignored
check_salt_ssh_python_versions_rejected $'3.10\n3.10.x' \
  "Invalid Python version '3.10.x' in SALT_SSH_PYTHON_VERSIONS"
check_salt_ssh_python_versions_rejected "${SSH_PYTHON_PATCH_VERSION} ${SSH_PYTHON_VERSION}" \
  "Python ${SSH_PYTHON_VERSION} is set more than once in SALT_SSH_PYTHON_VERSIONS"
# Python versions without a lock file in Salt are not supported
check_salt_ssh_python_versions_rejected "${SSH_PYTHON_VERSION} 2.7" \
  "Python 2.7 in SALT_SSH_PYTHON_VERSIONS is not supported by Salt"
# Targets with the Python version of salt-master use the default thin
ONEDIR_PYTHON_VERSION="$(docker run --rm --platform "${PLATFORM}" --entrypoint /opt/saltstack/salt/bin/python3 \
  "${IMAGE_NAME}" -c 'import sys; print("{}.{}".format(*sys.version_info))' || error "salt-master Python version")"
check_salt_ssh_python_versions_rejected "${SSH_PYTHON_VERSION} ${ONEDIR_PYTHON_VERSION}" \
  "Python ${ONEDIR_PYTHON_VERSION} in SALT_SSH_PYTHON_VERSIONS is the Python version of salt-master"

# Start a target with a different Python version
echo "==> Building salt-ssh Python ${SSH_PYTHON_VERSION} target image (${PLATFORM}) ..."
docker build --platform "${PLATFORM}" --build-arg PYTHON_VERSION="${SSH_PYTHON_VERSION}" \
  --tag "${SSH_PYTHON_TARGET_IMAGE}" "${SCRIPT_PATH}/target-python" ||
  error "salt-ssh Python ${SSH_PYTHON_VERSION} target image built"
ok "salt-ssh Python ${SSH_PYTHON_VERSION} target image built"

echo "==> Starting salt-ssh Python ${SSH_PYTHON_VERSION} target ..."
docker run --detach --name "${SSH_PYTHON_TARGET_NAME}" --hostname "${SSH_PYTHON_TARGET_NAME}" \
  --network "${SSH_NETWORK}" --platform "${PLATFORM}" \
  "${SSH_PYTHON_TARGET_IMAGE}" >/dev/null || error "salt-ssh Python ${SSH_PYTHON_VERSION} target started"
printf 'root:%s\n' "${SSH_TARGET_PASSWORD}" |
  docker exec --interactive "${SSH_PYTHON_TARGET_NAME}" chpasswd ||
  error "salt-ssh Python ${SSH_PYTHON_VERSION} target password set"
ok "salt-ssh Python ${SSH_PYTHON_VERSION} target started"

# Use the Python version installed through SALT_SSH_PYTHON_VERSIONS with ssh_ext_alternatives
echo "==> Creating ssh configuration file with ssh_ext_alternatives ..."
cat >"${SCRIPT_PATH}/config/ssh.conf" <<EOF
ssh_ext_alternatives:
  ${SSH_PYTHON_NAMESPACE}:
    py-version: [${SSH_PYTHON_VERSION/./, }]
    path: ${SSH_PYTHON_SALT_PATH}
    auto_detect: True
    py_bin: ${SSH_PYTHON_DIR}/bin/python-isolated
EOF
ok "ssh config created"

echo "==> Starting docker-salt-master (${PLATFORM}) with SALT_SSH_PYTHON_VERSIONS=${SSH_PYTHON_PATCH_VERSION} ..."
start_container_and_wait \
  --network "${SSH_NETWORK}" \
  --env SALT_SSH_PYTHON_VERSIONS="${SSH_PYTHON_PATCH_VERSION}" \
  --volume "${SCRIPT_PATH}/roots":/home/salt/data/srv:ro \
  --volume "${SCRIPT_PATH}/salt-ssh":/home/salt/data/salt-ssh:ro \
  --volume "${KEYS_DIR}":/home/salt/data/keys ||
  error "container started"
ok "container started"

# Python versions are installed before salt-master starts, and it may take longer than BOOTUP_WAIT_SECONDS
echo "==> Waiting for Python ${SSH_PYTHON_PATCH_VERSION} to be installed ..."
for _ in {1..30}; do
  docker-exec test -x "${SSH_PYTHON_DIR}/bin/python-isolated" && break
  sleep 2
done

echo "==> Checking Python ${SSH_PYTHON_VERSION} environment ..."
output="$(docker-exec-as-salt "${SSH_PYTHON_DIR}/bin/python-isolated" -c \
  'import sys, tornado; print("{}.{}.{} {}".format(*sys.version_info[:3], tornado.version))' ||
  error "Python ${SSH_PYTHON_VERSION} environment")"
LOCKED_TORNADO_VERSION="$(docker-exec grep -oP '^tornado==\K\S+' "/opt/salt-ssh/locks/${SSH_PYTHON_VERSION}.lock" ||
  error "tornado in the Python ${SSH_PYTHON_VERSION} lock file of Salt")"
check_equal "${output}" "${SSH_PYTHON_PATCH_VERSION} ${LOCKED_TORNADO_VERSION}" \
  "Python ${SSH_PYTHON_VERSION} environment with the packages pinned by the lock file of Salt"

# The onedir is the only Salt installation: the environment only has the packages of the thin
docker-exec-as-salt "${SSH_PYTHON_DIR}/bin/python-isolated" -c 'import salt' 2>/dev/null &&
  error "salt is not installed in the Python ${SSH_PYTHON_VERSION} environment"
ok "salt is not installed in the Python ${SSH_PYTHON_VERSION} environment"

echo "==> Deploying salt-ssh key to ${SSH_PYTHON_TARGET_NAME} ..."
output="$(salt-ssh --out=json -i --key-deploy --passwd "${SSH_TARGET_PASSWORD}" salt-ssh-python test.ping ||
  error "salt-ssh -i --key-deploy (Python ${SSH_PYTHON_VERSION})")"
check_equal "$(jq -rM '."salt-ssh-python"' <<<"${output}")" true "salt-ssh -i --key-deploy test.ping (Python ${SSH_PYTHON_VERSION})"

# salt-call adds <thin_dir>/<namespace>/pyall to sys.path when it runs from an alternative
echo "==> Checking salt-ssh uses ssh_ext_alternatives on ${SSH_PYTHON_TARGET_NAME} ..."
output="$(salt-ssh --out=json salt-ssh-python grains.item pythonpath || error "salt-ssh grains.item pythonpath")"
echo "${output}"
check_equal "$(jq -rM --arg dir "/${SSH_PYTHON_NAMESPACE}/pyall" '."salt-ssh-python".pythonpath | any(endswith($dir))' <<<"${output}")" \
  true "salt-ssh runs salt from the ${SSH_PYTHON_NAMESPACE} alternative"

# A restart reuses the working environment instead of installing it again
echo "==> Restarting docker-salt-master to check the Python ${SSH_PYTHON_VERSION} environment is reused ..."
docker restart "${CONTAINER_NAME}" >/dev/null || error "container restarted"
REUSE_MESSAGE="Using the existing Python ${SSH_PYTHON_PATCH_VERSION} environment"
for _ in {1..30}; do
  logs="$(docker-logs 2>&1 || true)"
  grep -qF "${REUSE_MESSAGE}" <<<"${logs}" && break
  sleep 2
done
assert_log_contains "${REUSE_MESSAGE}" "Python ${SSH_PYTHON_VERSION} environment reused after restart"
