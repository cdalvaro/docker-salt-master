#!/usr/bin/env bash

set -e

source "${SALT_RUNTIME_DIR}/functions.sh"

# Copy minion keys
copy_minion_keys

# Configure salt-master
configure_salt_master

echo "Starting salt-master..."
exec salt-master
