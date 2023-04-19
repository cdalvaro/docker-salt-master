#!/usr/bin/env bash

set -o errexit
set -o pipefail

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_debug
#   DESCRIPTION:  Echo debug information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_debug() {
  if [[ "${DEBUG,,}" == true || "${ECHO_DEBUG,,}" == true ]]; then
    echo "[DEBUG] - $*"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_info
#   DESCRIPTION:  Echo information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_info() {
  echo "[INFO] - $*"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_warn
#   DESCRIPTION:  Echo warning information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_warn() {
  (>&2 echo "[WARN] - $*")
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_error
#   DESCRIPTION:  Echo errors to stderr.
#----------------------------------------------------------------------------------------------------------------------
function log_error()
{
  (>&2 echo "[ERROR] - $*")
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  exec_as_salt
#   DESCRIPTION:  Execute the pass command as the `SALT_USER` user.
#----------------------------------------------------------------------------------------------------------------------
function exec_as_salt()
{
  if [[ $(whoami) == "${SALT_USER}" ]]; then
    $@
  else
    sudo -HEu "${SALT_USER}" "$@"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_arm64
#   DESCRIPTION:  Check whether the platform is ARM 64-bits or not.
#----------------------------------------------------------------------------------------------------------------------
function is_arm64()
{
  uname -m | grep -qE 'arm64|aarch64'
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_pkgs
#   DESCRIPTION:  Install packages using apt-get install.
#----------------------------------------------------------------------------------------------------------------------
function install_pkgs()
{
  apt-get install --no-install-recommends --yes $@
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  download
#   DESCRIPTION:  Download the content from the given URL and save it into the specified file.
#     ARGUMENTS:
#             1:  URL where the file is hosted.
#             2:  Filename (with path) for the downloaded file.
#----------------------------------------------------------------------------------------------------------------------
function download()
{
  local URL="$1"
  local FILE_NAME="$2"

  local WGET_ARGS=(--quiet)

  log_info "Downloading ${FILE_NAME} from ${URL} ..."
  wget ${WGET_ARGS[@]} -O "${FILE_NAME}" "${URL}"
  if [[ -f "${FILE_NAME}" ]]; then
    log_debug "Success!"
  else
    log_error "Failed to download ${URL}"
    exit 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_sha256
#   DESCRIPTION:  Compute the SHA256 hash for the given file and check if it matches the expected one.
#     ARGUMENTS:
#             1:  The file to check.
#             2:  The expected SHA256 checksum.
#----------------------------------------------------------------------------------------------------------------------
function check_sha256()
{
  local FILE="${1}"
  local SHA256="${2}"

  log_info "Checking ${FILE} SHA256 hash ..."
  if echo "${SHA256}  ${FILE}" | shasum -a 256 -c --status -; then
    log_debug "SHA256 hash for ${FILE} matches! (${SHA256})"
  else
    local HASH=$(shasum -a 256 "${FILE}" | awk '{print $1}')
    log_error "SHA256 checksum mismatch for ${FILE}"
    log_error "Expected: ${SHA256}"
    log_error "     Got: ${HASH}"
    exit 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  extract
#   DESCRIPTION:  Extract the given .tar.gz into the current directory.
#     ARGUMENTS:
#             1:  The file to extract.
#----------------------------------------------------------------------------------------------------------------------
function extract()
{
  local FILE="${1}"
  log_info "Unpacking file: ${FILE}"
  tar xzf "${FILE}" --strip-components 1
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  add_salt_repository
#   DESCRIPTION:  Add salt repository to packages sources.
#----------------------------------------------------------------------------------------------------------------------
function add_salt_repository()
{
  local arch=amd64
  is_arm64 && arch=arm64
  source /etc/os-release

  local keyring_file="/etc/apt/keyrings/salt-archive-keyring.gpg"
  local root_url="https://repo.saltproject.io/salt/py3/ubuntu/${VERSION_ID:?}/${arch}"

  download "${root_url}/SALT-PROJECT-GPG-PUBKEY-2023.gpg" "${keyring_file}"
  echo "deb [signed-by=${keyring_file} arch=${arch}] ${root_url}/minor/${SALT_VERSION} ${VERSION_CODENAME:?} main" > /etc/apt/sources.list.d/salt.list
}
