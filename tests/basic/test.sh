#!/usr/bin/env bash

set -e
[ "${DEBUG}" == true ] && set -vx

echo "🧪 Running basic tests ..."

IMAGE_NAME=${IMAGE_NAME:-cdalvaro/docker-salt-master}
CONTAINER_NAME=salt_master
PLATFORM=${PLATFORM:-$(docker version --format='{{.Server.Os}}/{{.Server.Arch}}')}
BOOTUP_WAIT_SECONDS=${BOOTUP_WAIT_SECONDS:-60}

function cleanup {
  echo "==> Removing ${CONTAINER_NAME} ..."
  docker container rm --force "${CONTAINER_NAME}"
}

trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) ..."
docker run --rm --detach --name "${CONTAINER_NAME}" \
  --publish 4505:4505 --publish 4506:4506 \
  --platform "${PLATFORM}" \
  "${IMAGE_NAME}" || ( echo "container started ❌"; exit 1 )
echo "container started ✅"

# Wait for salt-master bootup
echo "==> Waiting ${BOOTUP_WAIT_SECONDS} seconds for the container to be ready ..."
sleep "${BOOTUP_WAIT_SECONDS}"

# Check salt version
echo "==> Checking salt version ..."
docker exec "${CONTAINER_NAME}" salt --versions
[[ "$(docker exec ${CONTAINER_NAME} salt --version)" == "salt $(cat VERSION)" ]] || ( echo "salt version ❌"; exit 1 )
echo "salt version ✅"

# Test image calling healthcheck
echo "==> Executing healthcheck ..."
docker exec "${CONTAINER_NAME}" /usr/local/sbin/healthcheck | grep -i 'true' || ( echo "healthcheck ❌"; exit 1 )
echo "healthcheck ✅"
