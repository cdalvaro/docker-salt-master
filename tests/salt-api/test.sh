#!/usr/bin/env bash

set -e
[ "${DEBUG}" == true ] && set -vx

echo "🧪 Running salt-api tests ..."

# https://stackoverflow.com/a/4774063/3398062
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

export SALTAPI_URL="https://localhost:8000/"
export SALTAPI_USER=salt_api
export SALTAPI_PASS=4wesome-Pass0rd
export SALTAPI_EAUTH=pam
export SALTAPI_TMP_DIR=${SALTAPI_TMP_DIR:-/tmp/salt-api}

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
ok "salt-api config created"

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with salt-api config ..."
start_container_and_wait \
  --publish 8000:8000 \
  --env SALT_API_SERVICE_ENABLED=true \
  --env SALT_API_USER_PASS="${SALTAPI_PASS}" \
  --volume "${SALTAPI_TMP_DIR}/config":/home/salt/data/config:ro \
|| error "container started"
ok "container started"

# Test salt-api authentication
echo "==> Getting salt-api token ..."
SALTAPI_TOKEN=$(curl -sSk "${SALTAPI_URL%/}/login" \
  -H "Accept: application/x-yaml" \
  -d username="${SALTAPI_USER}" \
  -d password="${SALTAPI_PASS}" \
  -d eauth="${SALTAPI_EAUTH}" | grep 'token:' | cut -d' ' -f 4)
[ -n "${SALTAPI_TOKEN}" ] || error "salt-api token"
ok "salt-api token"

# Test salt-api command
echo "==> Testing curl command ..."
curl -sSk "${SALTAPI_URL}" \
  -H "Accept: application/x-yaml" \
  -H "X-Auth-Token: ${SALTAPI_TOKEN}" \
  -d client=runner \
  -d tgt='*' \
  -d fun=test.stream \
| grep -i 'true' || error "curl command"
ok "curl command"

# Install salt-pepper
echo "==> Installing salt-pepper ..."
pip3 install salt-pepper || error "pepper installed"
ok "pepper installed"

# Test salt-pepper
echo "==> Testing salt-pepper ..."
pepper --client runner test.stream || error "pepper test.stream"
ok "pepper test.stream"
