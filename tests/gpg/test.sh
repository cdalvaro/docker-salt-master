#!/usr/bin/env bash

echo "🧪 Running gpg tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) config ..."
start_container_and_wait \
  --volume "${SCRIPT_PATH}/roots":/home/salt/data/srv:ro \
  --volume "${SCRIPT_PATH}/keys":/home/salt/data/keys \
|| error "container started"
ok "container started"

setup_and_start_salt_minion || error "salt-minion started"
ok "salt-minion started"

# Test foo pillar
echo "==> Getting gpg encrypted pillar.foo.encrypted from minion ..."
PILLAR_FOO="$( salt "${TEST_MINION_ID}" pillar.get 'foo:encrypted' || error "Unable to get pillar 'foo:encrypted'" )"
echo "${PILLAR_FOO}"
echo -n "${PILLAR_FOO}" | grep -q 'Hello, test.minion!' || error "gpg encrypted pillar.foo.encrypted"
ok "gpg encrypted pillar.foo.encrypted"
