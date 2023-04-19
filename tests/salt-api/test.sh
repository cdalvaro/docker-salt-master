#!/usr/bin/env bash

echo "🧪 Running salt-api tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

export SALTAPI_URL="https://localhost:8000/"
export SALTAPI_USER=salt_api
export SALTAPI_PASS=4wesome-Pass0rd
export SALTAPI_EAUTH=pam

# Create configuration files
echo "==> Creating salt-api configuration file ..."
mkdir -p "${SCRIPT_PATH}/config"
cat > "${SCRIPT_PATH}/config/salt-api.conf" <<EOF
# Breaking change from 3006
# https://docs.saltproject.io/en/latest/topics/netapi/netapi-enable-clients.html
netapi_enable_clients:
  - local
  - local_async
  - local_batch
  - local_subset
  - runner
  - runner_async

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
  --env SALT_API_SERVICE_ENABLED=True \
  --env SALT_API_USER_PASS="${SALTAPI_PASS}" \
|| error "container started"
ok "container started"

# Test salt-api authentication
echo "==> Getting salt-api token ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL%/}/login" \
  -H "Accept: application/x-yaml" \
  -d username="${SALTAPI_USER}" \
  -d password="${SALTAPI_PASS}" \
  -d eauth="${SALTAPI_EAUTH}")"
echo "${CURL_OUTPUT}"

SALTAPI_TOKEN=
SALTAPI_TOKEN="$(echo -n "${CURL_OUTPUT}" | grep -Ei 'token: ([^\s]+)' | awk '{print $2}')"
[ -n "${SALTAPI_TOKEN}" ] || error "salt-api token"
ok "salt-api token"

# Test salt-api command
echo "==> Testing curl command ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL}" \
  -H "Accept: application/x-yaml" \
  -H "X-Auth-Token: ${SALTAPI_TOKEN}" \
  -d client=runner \
  -d tgt='*' \
  -d fun=test.stream)"
echo "${CURL_OUTPUT}"

echo -n "${CURL_OUTPUT}" | grep -i true || error "curl command"
ok "curl command"

# Stop and start with salt-api pass via file
echo "==> Stopping previous container ..."
cleanup

echo "==> Starting docker-salt-master (${PLATFORM}) with salt-api config and password via file ..."
export SALT_API_USER_PASS_FILE=salt_api_user_pass
echo -n "${SALTAPI_PASS}" > "./${SALT_API_USER_PASS_FILE}"
start_container_and_wait \
  --publish 8000:8000 \
  --env SALT_API_SERVICE_ENABLED=True \
  --env SALT_API_USER_PASS_FILE="/run/secrets/${SALT_API_USER_PASS_FILE}" \
  --volume "$(pwd)/${SALT_API_USER_PASS_FILE}":/run/secrets/${SALT_API_USER_PASS_FILE}:ro \
|| error "container started"
ok "container started"

# Test salt-api authentication
echo "==> Getting salt-api token (pass via file) ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL%/}/login" \
  -H "Accept: application/x-yaml" \
  -d username="${SALTAPI_USER}" \
  -d password="${SALTAPI_PASS}" \
  -d eauth="${SALTAPI_EAUTH}")"
echo "${CURL_OUTPUT}"

SALTAPI_TOKEN=
SALTAPI_TOKEN="$(echo -n "${CURL_OUTPUT}" | grep -Ei 'token: ([^\s]+)' | awk '{print $2}')"
[ -n "${SALTAPI_TOKEN}" ] || error "salt-api token"
ok "salt-api token"

# Test salt-api command via curl
echo "==> Testing curl command (pass via file) ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL}" \
  -H "Accept: application/x-yaml" \
  -H "X-Auth-Token: ${SALTAPI_TOKEN}" \
  -d client=runner \
  -d tgt='*' \
  -d fun=test.stream)"
echo "${CURL_OUTPUT}"

echo -n "${CURL_OUTPUT}" | grep -i true || error "curl command (pass via file)"
ok "curl command (pass via file)"

# Install salt-pepper
echo "==> Installing salt-pepper ..."
pip3 install salt-pepper || error "pepper installed"
ok "pepper installed"

# Test minion connection
setup_and_start_salt_minion || error "salt-minion started"
ok "salt-minion started"

# Test pepper with salt-minion
echo "==> Testing pepper with salt-minion (test.ping) ..."
pepper "${TEST_MINION_ID}" test.ping || error "pepper test.ping"
ok "pepper test.ping"
