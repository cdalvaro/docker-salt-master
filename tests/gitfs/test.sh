#!/usr/bin/env bash

echo "🧪 Running gitfs tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

export GITFS_KEYS_DIR=${GITFS_KEYS_DIR:-tests/gitfs/data/keys/gitfs}

# Check gitfs keys are present
echo "==> Checking gitfs keys are present ..."
if [[ ! -f "${GITFS_KEYS_DIR}/gitfs_ssh" || ! -f "${GITFS_KEYS_DIR}/gitfs_ssh.pub" ]]; then
  error "gitfs keys not found at ${GITFS_KEYS_DIR}"
fi
ok "gitfs keys"

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with ed25519 ssh key ..."
start_container_and_wait \
  --volume "$(pwd)/${GITFS_KEYS_DIR%%/gitfs}":/home/salt/data/keys \
|| error "container started"
ok "container started"

# Check pygit2 is installed
output=$(docker-exec salt-master --versions)

# shellcheck disable=SC2016
CURRENT_VERSION="$(echo -n "${output}" | grep -Ei 'pygit2: ([^\s]+)' | awk '{print $2}')"
EXPECTED_VERSION="1.14.0"
check_equal "${CURRENT_VERSION%%-*}" "${EXPECTED_VERSION%%-*}" "pygit2 version"

# Update repositories
echo "==> Updating gitfs repositories ..."
salt-run cache.clear_git_lock gitfs type=update
UPDATE_REPOS="$( salt-run fileserver.update )"
echo "${UPDATE_REPOS}" | grep -qi true || error "update gitfs"
ok "update gitfs"

# Check gitfs files
echo "==> Checking gitfs files ..."
FILE_LIST=$( salt-run fileserver.file_list )
echo "${FILE_LIST}"
[[ "${FILE_LIST}" == *test.txt* ]] || error "gitfs files"
ok "gitfs files"

# Test minion connection
setup_and_start_salt_minion || error "salt-minion started"
ok "salt-minion started"

# Test pillar
echo "==> Checking gitfs pillar docker-salt-master-test:email content from minion ..."
PILLAR_CONTENT="$( salt "${TEST_MINION_ID}" pillar.get 'docker-salt-master-test:email' || error "Unable to get pillar 'docker-salt-master-test:email'" )"
echo "${PILLAR_CONTENT}"
echo -n "${PILLAR_CONTENT}" | grep -q 'github@cdalvaro.io' || error "Check gitfs pillar 'docker-salt-master-test:email'"
ok "Check gitfs pillar 'docker-salt-master-test:email'"

# Test gitfs deploy
echo "==> Checking gitfs top.sls (state.apply) ..."
salt "${TEST_MINION_ID}" state.apply
[[ -f /tmp/my_file.txt ]] || error "Check gitfs top.sls applied"
ok "Check gitfs top.sls applied"
