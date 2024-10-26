#!/usr/bin/env bash
# shellcheck disable=SC2016

echo "🧪 Running salt-minion tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
# shellcheck source=tests/lib/common.sh
source "${COMMON_FILE}"
trap cleanup EXIT

export SALT_MINION_ID=test.builtin.minion
KEYS_DIR="${SCRIPT_PATH}/keys"

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with salt-minion enabled ..."
start_container_and_wait \
  --env SALT_MINION_ENABLED=True \
  --env SALT_MINION_ID || error "container started"
ok "container started"

# Test salt-minion is running inside the container
echo "==> Test salt-minion is running inside the container ..."
docker-exec bash -c 'test -n "$(ps aux | grep salt-minion | grep -v grep)"' || error "salt-minion is not running inside the container"
ok "salt-minion is running inside the container"

# Test salt-minion version
echo "==> Test salt-minion version with test.version ..."
TEST_VERSION_OUTPUT="$(docker-exec salt --out=json "${SALT_MINION_ID}" test.version)"
MINION_VERSION="$(echo -n "${TEST_VERSION_OUTPUT}" | jq -rM --arg mID "${SALT_MINION_ID}" '.[$mID]')"
check_equal "${MINION_VERSION}" "$(cat VERSION)" "salt-minion version"

# Stop container
echo "==> Stopping previous container ..."
cleanup || error "Unable to stop previour container"

# Test salt-minion test.ping with master signed keys
echo "==> Starting docker-salt-master (${PLATFORM}) with salt-minion enabled and master signed keys ..."
mkdir -p "${KEYS_DIR}"
start_container_and_wait \
  --env SALT_MINION_ENABLED=True \
  --env SALT_MINION_ID \
  --env SALT_MASTER_SIGN_PUBKEY=True \
  --volume "${KEYS_DIR}":/home/salt/data/keys || error "container started"
ok "container started"

# Test that minion keys are inside the expected directory
echo "==> Checking keys directory ..."
[[ -d "${KEYS_DIR}/${SALT_MINION_ID}" ]] || error "keys directory"
ok "keys directory"

# Test salt-minion test.ping
echo "==> Test salt-minion test.ping ..."
docker-exec salt "${SALT_MINION_ID}" test.ping || error "salt-minion test.ping"
ok "salt-minion test.ping"

# Stop container
echo "==> Stopping previous container ..."
cleanup || error "Unable to stop previour container"

# Test salt-minion with custom configuration
echo "==> Creating salt-minion configuration file ..."
EXPECTED_PYENV_ROOT_PATH=/usr/local/pyenv-cdalvaro
MINION_CONFIG_DIR="${SCRIPT_PATH}/minion_config"
mkdir -p "${MINION_CONFIG_DIR}"
cat >"${MINION_CONFIG_DIR}/pyenv.conf" <<EOF
pyenv.root: ${EXPECTED_PYENV_ROOT_PATH}
EOF
ok "salt-minion pyenv config file created"

# Test salt-minion pyenv config with custom configuration
echo "==> Starting docker-salt-master (${PLATFORM}) with custom salt-minion configuration ..."
start_container_and_wait \
  --env SALT_MINION_ENABLED=True \
  --env SALT_MINION_ID \
  --env SALT_MASTER_SIGN_PUBKEY=True \
  --volume "${KEYS_DIR}":/home/salt/data/keys \
  --volume "${MINION_CONFIG_DIR}:/home/salt/data/minion_config" || error "container started"
ok "container started"

# Test the minion is responding
echo "==> Test salt-minion is responding when reusing previous keys ..."
docker-exec salt "${SALT_MINION_ID}" test.ping || error "salt-minion test.ping with previous keys"
ok "salt-minion test.ping with previous keys"

# Test the configuration is loaded properly
echo "==> Test salt-minion pyenv configuration ..."
TEST_PYENV_OUTPUT="$(docker-exec salt --out=json "${SALT_MINION_ID}" config.get 'pyenv.root')"
PYENV_ROOT_PATH="$(echo -n "${TEST_PYENV_OUTPUT}" | jq -rM --arg mID "${SALT_MINION_ID}" '.[$mID]')"
check_equal "${PYENV_ROOT_PATH}" "${EXPECTED_PYENV_ROOT_PATH}" "salt-minion pyenv configuration"
