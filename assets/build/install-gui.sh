#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

export DEBIAN_FRONTEND=noninteractive

FUNCTIONS_FILE="${SALT_BUILD_DIR}/functions.sh"
# shellcheck source=assets/build/functions.sh
source "${FUNCTIONS_FILE}"

download "https://github.com/erwindon/SaltGUI/archive/refs/tags/${SALTGUI_VERSION}.tar.gz" "saltgui.tar.gz"
check_sha256 "saltgui.tar.gz" "${SALTGUI_SHA256}"
extract "saltgui.tar.gz" "saltgui"

log_info "Moving SaltGUI files to /opt/saltgui..."
mkdir -p /opt
mv saltgui /opt/saltgui
chown "${SALT_USER}": /opt/saltgui
