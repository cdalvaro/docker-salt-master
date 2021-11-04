#!/usr/bin/env bash

set -e
[ "${DEBUG}" == true ] && set -vx

echo "🧪 Running gitfs tests ..."

# https://stackoverflow.com/a/4774063/3398062
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
echo "==> Starting docker-salt-master (${PLATFORM}) with RSA 4096 ssh key ..."
start_container_and_wait \
  --volume "$(pwd)/tests/gitfs/config":/home/salt/data/config:ro \
  --volume "$(pwd)/${GITFS_KEYS_DIR%%/gitfs}":/home/salt/data/keys \
|| error "container started"
ok "container started"

# Update repositories
echo "==> Updating gitfs repositories ..."
salt-run cache.clear_git_lock gitfs type=update
UPDATE_REPOS="$( salt-run fileserver.update )"
echo "${UPDATE_REPOS}" | grep -qi 'true' || error "update gitfs"
ok "update gitfs"

# Check pillars
echo "==> Checking gitfs files ..."
FILE_LIST=$( salt-run fileserver.file_list )
echo "${FILE_LIST}"
[[ "${FILE_LIST}" == *test.txt* ]] || error "gitfs files"
ok "gitfs files"
