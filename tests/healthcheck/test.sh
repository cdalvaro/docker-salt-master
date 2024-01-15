#!/usr/bin/env bash

echo "🧪 Running healthcheck tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) ..."
start_container_and_wait \
  --health-cmd='/usr/local/sbin/healthcheck' \
  --health-start-period=30s \
  --health-interval=10s \
  --health-timeout=10s \
  --health-retries=3 \
|| error "container started"
ok "container started"

# Test image calling healthcheck
echo "==> Executing healthcheck ..."
docker-exec /usr/local/sbin/healthcheck || error "healthcheck"
ok "healthcheck"

# Check container is healthy
echo "==> Checking container status ..."
HEALTHCHECK_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}")
check_equal "${HEALTHCHECK_STATUS}" "healthy" "container is healthy"

# Force salt-master to die
echo "==> Forcing salt-master to die ..."
docker-exec bash -c 'supervisorctl stop salt-master' || error "salt-master killed"
sleep 60

# Check container is unhealthy
echo "==> Checking health status ..."
HEALTHCHECK_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}")
check_equal "${HEALTHCHECK_STATUS}" "unhealthy" "container is unhealthy"
