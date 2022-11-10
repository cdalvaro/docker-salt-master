#!/usr/bin/env bash

echo "🧪 Running basic tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) ..."
start_container_and_wait || error "container started"
ok "container started"

# Check salt version
echo "==> Checking salt-master version ..."
docker-exec salt-master --versions
EXPECTED_VERSION="$(cat VERSION)"
CURRENT_VERSION="$(docker-exec salt-master --version)"
check_equal "${CURRENT_VERSION}" "salt-master ${EXPECTED_VERSION%%-*}" "salt-master --version"

# Test image calling healthcheck
echo "==> Executing healthcheck ..."
docker-exec /usr/local/sbin/healthcheck | grep -i true || error "healthcheck"
ok "healthcheck"

# Check salt-minion is not installed
# shellcheck disable=SC2016
docker-exec bash -c 'test -z "$(command -v salt-minion)"' || error "salt-minion is installed inside the container"
ok "salt-minion is not installed inside the container"

# shellcheck disable=SC2016
docker-exec bash -c 'test -z "$(ps aux | grep salt-minion | grep -v grep)"' || error "salt-minion is running inside the container"
ok "salt-minion is not running inside the container"

# Test minion connection
setup_and_start_salt_minion || error "salt-minion started"
ok "salt-minion started"

salt "${TEST_MINION_ID}" test.ping || error "${TEST_MINION_ID} ping"
ok "${TEST_MINION_ID} ping"
