#!/usr/bin/env bash

set -e
[ "${DEBUG}" == true ] && set -vx

echo "🧪 Running gitfs tests ..."

IMAGE_NAME=${IMAGE_NAME:-cdalvaro/docker-salt-master}
CONTAINER_NAME=salt_master
PLATFORM=${PLATFORM:-$(docker version --format='{{.Server.Os}}/{{.Server.Arch}}')}
BOOTUP_WAIT_SECONDS=${BOOTUP_WAIT_SECONDS:-60}

function cleanup {
  echo "==> Removing ${CONTAINER_NAME} ..."
  docker container rm --force "${CONTAINER_NAME}"
}

# trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with RSA 4096 ssh key ..."
docker run --rm --detach --name "${CONTAINER_NAME}" \
  --publish 4505:4505 --publish 4506:4506 \
  --platform "${PLATFORM}" \
  --volume "$(pwd)/tests/gitfs/config":/home/salt/data/config:ro \
  --volume "$(pwd)/tests/gitfs/data/keys":/home/salt/data/keys \
  "${IMAGE_NAME}" || ( echo "container started ❌"; exit 1 )
echo "container started ✅"

# Wait for salt-master bootup
echo "==> Waiting ${BOOTUP_WAIT_SECONDS} seconds for the container to be ready ..."
sleep "${BOOTUP_WAIT_SECONDS}"

# Check pillars
echo "==> Checking gitfs files ..."
# docker exec "${CONTAINER_NAME}" salt-run cache.clear_git_lock gitfs type=update
# docker exec "${CONTAINER_NAME}" salt-run fileserver.update
FILE_LIST=$(docker exec "${CONTAINER_NAME}" salt-run fileserver.file_list)
echo "${FILE_LIST}"
[[ "${FILE_LIST}" == *test.txt* ]] || ( echo "gitfs files ❌"; exit 1 )
echo "gitfs files ✅"
