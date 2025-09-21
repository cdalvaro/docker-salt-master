#!/usr/bin/env bash
# shellcheck disable=SC2016

echo "🧪 Running basic tests ..."

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

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) ..."
start_container_and_wait || error "container started"
ok "container started"

# Check salt versions
EXPECTED_VERSION="${SALT_VERSION}"

echo "==> Checking salt-master version ..."
output=$(docker-exec salt-master --versions)
echo "${output}"

CURRENT_MASTER_VERSION="$(echo -n "${output}" | grep -Ei 'salt: ([^\s]+)' | awk '{print $2}')"
check_equal "${CURRENT_MASTER_VERSION%%-*}" "${EXPECTED_VERSION%%-*}" "salt-master version"

echo "==> Checking salt-minion version ..."
output=$(docker-exec salt-minion --versions)
echo "${output}"

CURRENT_MINION_VERSION="$(echo -n "${output}" | grep -Ei 'salt: ([^\s]+)' | awk '{print $2}')"
check_equal "${CURRENT_MINION_VERSION%%-*}" "${EXPECTED_VERSION%%-*}" "salt-minion version"

echo "==> Checking salt-minion service ..."
docker-exec bash -c 'test -z "$(ps aux | grep salt-minion | grep -v grep)"' || error "salt-minion is running inside the container by default"
ok "salt-minion is not running inside the container"

# Test minion connection
setup_and_start_salt_minion || error "salt-minion started"
ok "salt-minion started"

salt "${TEST_MINION_ID}" test.ping || error "${TEST_MINION_ID} ping"
ok "${TEST_MINION_ID} ping"

echo "==> Checking salt user permissions ..."

# Test salt home permissions
docker-exec bash -c 'test $(stat -c "%U:%G" "${SALT_HOME}") = "${SALT_USER}:${SALT_USER}"' || error "salt home permissions"
ok "salt home permissions"

# Test salt PUID and PGID
EXPECTED_USER_ID="salt:x:$(id -u):$(id -g):Salt:/home/salt:/usr/sbin/nologin"
CURRENT_USER_ID="$(docker-exec bash -c 'getent passwd salt')"
check_equal "${CURRENT_USER_ID}" "${EXPECTED_USER_ID}" "salt user id"

EXPECTED_GROUP_ID="salt:x:$(id -g):"
CURRENT_GROUP_ID="$(docker-exec bash -c 'getent group salt')"
check_equal "${CURRENT_GROUP_ID}" "${EXPECTED_GROUP_ID}" "salt group id"

echo "==> Checking there is not ubuntu user/group ..."
docker-exec bash -c 'getent passwd ubuntu >/dev/null 2>&1' && error "ubuntu user is present inside the container"
ok "There is not ubuntu user inside the container"

docker-exec bash -c 'getent group ubuntu >/dev/null 2>&1' && error "ubuntu group is present inside the container"
ok "There is not ubuntu group inside the container"
