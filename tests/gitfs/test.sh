#!/usr/bin/env bash

set -e
[ "${DEBUG}" == true ] && set -vx

# https://stackoverflow.com/a/4774063/3398062
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"

echo "🧪 Running gitfs tests ..."

trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with RSA 4096 ssh key ..."
start_container_and_wait \
  --volume "$(pwd)/tests/gitfs/config":/home/salt/data/config:ro \
  --volume "$(pwd)/tests/gitfs/data/keys":/home/salt/data/keys \
|| error "container started"
ok "container started"

# Update repositories
echo "==> Updating gitfs repositories ..."
docker exec "${CONTAINER_NAME}" salt-run cache.clear_git_lock gitfs type=update
UPDATE_REPOS="$(docker exec "${CONTAINER_NAME}" salt-run fileserver.update)"
echo "${UPDATE_REPOS}" | grep -qi 'true' || error "update gitfs"
ok "update gitfs"

# Check pillars
echo "==> Checking gitfs files ..."
FILE_LIST=$(docker exec "${CONTAINER_NAME}" salt-run fileserver.file_list)
echo "${FILE_LIST}"
[[ "${FILE_LIST}" == *test.txt* ]] || error "gitfs files"
ok "gitfs files"
