#!/usr/bin/env bash
# shellcheck disable=SC2016

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

# Check salt versions
EXPECTED_VERSION="$(cat VERSION)"

echo "==> Checking salt-master version ..."
output=$(docker-exec salt-master --versions)
echo "${output}"

CURRENT_MASTER_VERSION="$(echo -n "${output}" | grep -Ei 'salt: ([^\s]+)' | awk '{print $2}')"
check_equal "${CURRENT_MASTER_VERSION%%-*}" "${EXPECTED_VERSION%%-*}" "salt-master version"

echo "==> Checking salt-minion version ..."
output=$(docker-exec salt-minion --versions)
echo "#{output}"

CURRENT_MINION_VERSION="$(echo -n "${output}" | grep -Ei 'salt: ([^\s]+)' | awk '{print $2}')"
check_equal "${CURRENT_MINION_VERSION%%-*}" "${EXPECTED_VERSION%%-*}" "salt-minion version"

docker-exec bash -c 'test -z "$(ps aux | grep salt-minion | grep -v grep)"' || error "salt-minion is running inside the container"
ok "salt-minion is not running inside the container"

# Test minion connection
setup_and_start_salt_minion || error "salt-minion started"
ok "salt-minion started"

salt "${TEST_MINION_ID}" test.ping || error "${TEST_MINION_ID} ping"
ok "${TEST_MINION_ID} ping"

# Test salt home permissions
docker-exec bash -c 'test $(stat -c "%U:%G" "${SALT_HOME}") = "${SALT_USER}:${SALT_USER}"' || error "salt home permissions"
ok "salt home permissions"
