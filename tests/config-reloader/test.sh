#!/usr/bin/env bash

echo "🧪 Running config-reloader tests ..."

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
  --env SALT_RESTART_MASTER_ON_CONFIG_CHANGE=True \
|| error "container started"
ok "container started"

# Get initial configuration values
echo "==> Checking initial configuration values ..."
FILE_BUFFER_SIZE="$(salt-run config.get file_buffer_size)"
YAML_UTF8="$(salt-run config.get yaml_utf8)"

FILE_BUFFER_SIZE_EXPECTED=1048576
YAML_UTF8_EXPECTED=

check_equal "${FILE_BUFFER_SIZE}" "${FILE_BUFFER_SIZE_EXPECTED}" "file_buffer_size"
check_equal "${YAML_UTF8}" "${YAML_UTF8_EXPECTED}" "yaml_utf8"

# Update fileserver config
echo "==> Updating file_buffer_size config ..."
FILE_BUFFER_SIZE_EXPECTED=2097152
sed -i "s/file_buffer_size:.*/file_buffer_size: ${FILE_BUFFER_SIZE_EXPECTED}/" "${SCRIPT_PATH}/config/fileserver.conf"
sleep 30 # Wait for the config to be reloaded

FILE_BUFFER_SIZE="$(salt-run config.get file_buffer_size)"
check_equal "${FILE_BUFFER_SIZE}" "${FILE_BUFFER_SIZE_EXPECTED}" "file_buffer_size"

# Create yaml_utf8 config
echo "==> Creating yaml_utf8 config ..."
YAML_UTF8_EXPECTED=True
cat > "${SCRIPT_PATH}/config/yaml_utf8.conf" <<EOF
# Enable extra routines for YAML renderer used states containing UTF characters.
yaml_utf8: ${YAML_UTF8_EXPECTED}
EOF
sleep 30 # Wait for the config to be reloaded

YAML_UTF8="$(salt-run config.get yaml_utf8)"
check_equal "${YAML_UTF8}" "${YAML_UTF8_EXPECTED}" "yaml_utf8"
