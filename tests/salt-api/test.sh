#!/usr/bin/env bash

set -e
[ "${DEBUG}" == true ] && set -vx

echo "🧪 Running salt-api tests ..."

IMAGE_NAME=${IMAGE_NAME:-cdalvaro/docker-salt-master}
CONTAINER_NAME=salt_master
PLATFORM=${PLATFORM:-$(docker version --format='{{.Server.Os}}/{{.Server.Arch}}')}
BOOTUP_WAIT_SECONDS=${BOOTUP_WAIT_SECONDS:-60}

export SALTAPI_URL="https://localhost:8000/"
export SALTAPI_USER=salt_api
export SALTAPI_PASS=4wesome-Pass0rd
export SALTAPI_EAUTH=pam
export SALTAPI_TMP_DIR=${SALTAPI_TMP_DIR:-/tmp/salt-api}

function cleanup {
  echo "==> Removing ${CONTAINER_NAME} ..."
  docker container rm --force "${CONTAINER_NAME}"
}

trap cleanup EXIT

# Create configuration files
echo "==> Creating salt-api configuration file ..."
mkdir -p "${SALTAPI_TMP_DIR}/config/"
cat > "${SALTAPI_TMP_DIR}/config/salt-api.conf" <<EOF
external_auth:
  ${SALTAPI_EAUTH}:
    ${SALTAPI_USER}:
      - .*
      - '@runner'
      - '@wheel'
      - '@jobs'
EOF
echo "salt-api config created ✅"

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with salt-api config ..."
docker run --rm --detach --name "${CONTAINER_NAME}" \
  --publish 4505:4505 --publish 4506:4506 --publish 8000:8000 \
  --env SALT_API_SERVICE_ENABLED=true \
  --env SALT_API_USER_PASS="${SALTAPI_PASS}" \
  --platform "${PLATFORM}" \
  --volume "${SALTAPI_TMP_DIR}/config":/home/salt/data/config:ro \
  "${IMAGE_NAME}" || ( echo "container started ❌"; exit 1 )
echo "container started ✅"

# Wait for salt-master bootup
echo "==> Waiting ${BOOTUP_WAIT_SECONDS} seconds for the container to be ready ..."
sleep "${BOOTUP_WAIT_SECONDS}"

# Test salt-api authentication
echo "==> Getting salt-api token ..."
SALTAPI_TOKEN=$(curl -sSk "${SALTAPI_URL%/}/login" \
  -H "Accept: application/x-yaml" \
  -d username="${SALTAPI_USER}" \
  -d password="${SALTAPI_PASS}" \
  -d eauth="${SALTAPI_EAUTH}" | grep 'token:' | cut -d' ' -f 4)
[ -n "${SALTAPI_TOKEN}" ] || ( echo "salt-api token ❌"; exit 1 )
echo "salt-api token ✅"

# Test salt-api command
echo "==> Testing curl command ..."
curl -sSk "${SALTAPI_URL}" \
  -H "Accept: application/x-yaml" \
  -H "X-Auth-Token: ${SALTAPI_TOKEN}" \
  -d client=runner \
  -d tgt='*' \
  -d fun=test.stream \
| grep -i 'true' || ( echo "curl command ❌"; exit 1 )
echo "curl command ✅"

# Install salt-pepper
echo "==> Installing salt-pepper ..."
pip3 install salt-pepper || ( echo "pepper installed ❌"; exit 1 )
echo "pepper installed ✅"

# Test salt-pepper
echo "==> Testing salt-pepper ..."
pepper -vvv --debug-http --ignore-ssl-errors --client runner test.stream|| ( echo "pepper test.stream ❌"; exit 1 )
echo "pepper test.stream ✅"
