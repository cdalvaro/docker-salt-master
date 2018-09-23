#!/usr/bin/env bash

set -e

source "${SALT_RUNTIME_DIR}/functions.sh"

# Copy minion keys
copy_minion_keys

exec salt-master --log-level=${SALT_LOG_LEVEL:-warning}

