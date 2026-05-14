#!/usr/bin/env bash

echo "🧪 Running gpg tests ..."

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
echo "==> Starting docker-salt-master (${PLATFORM}) config ..."
start_container_and_wait \
  --volume "${SCRIPT_PATH}/roots":/home/salt/data/srv:ro \
  --volume "${SCRIPT_PATH}/keys":/home/salt/data/keys ||
  error "container started"
ok "container started"

setup_and_start_salt_minion || error "salt-minion started"
ok "salt-minion started"

# Test foo pillar
echo "==> Getting gpg encrypted pillar.foo.encrypted from minion ..."
STATE_OUTPUT="$(salt --out=json --static "${TEST_MINION_ID}" state.apply check_gpg_pillar || error "Unable to apply state 'check_gpg_pillar'")"
echo "${STATE_OUTPUT}"
PILLAR_CHECK_RESULT="$(echo -n "${STATE_OUTPUT}" | jq -rM --arg mID "${TEST_MINION_ID}" '.[$mID] | to_entries[0].value.result')"
check_equal "${PILLAR_CHECK_RESULT}" 'true' "gpg encrypted pillar.foo.encrypted"
