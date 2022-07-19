#!/usr/bin/env bash

set -e
[ "${DEBUG,,}" == true ] && set -vx

echo "🧪 Running basic tests ..."

# https://stackoverflow.com/a/4774063/3398062
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) ..."
start_container_and_wait || error "container started"
ok "container started"

# Check salt version
echo "==> Checking salt-master version ..."
docker-exec salt-master --versions
[[ "$(docker-exec salt-master --version)" == "salt-master $(cat VERSION)" ]] || error "salt-master version"
ok "salt-master version"

# Test image calling healthcheck
echo "==> Executing healthcheck ..."
docker-exec /usr/local/sbin/healthcheck | grep -i true || error "healthcheck"
ok "healthcheck"
