#!/usr/bin/env bash

set -e

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
#          NAME:  is_arm32
#   DESCRIPTION:  Check whether the platform is ARM 32-bits or not.
#----------------------------------------------------------------------------------------------------------------------
function is_arm32()
{
  uname -m | grep -qE 'armv7l'
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_arm32
#   DESCRIPTION:  Check whether the platform is ARM 64-bits or not.
#----------------------------------------------------------------------------------------------------------------------
function is_arm64()
{
  uname -m | grep -qE 'arm64|aarch64'
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_arm32
#   DESCRIPTION:  Check whether the platform is ARM or not.
#----------------------------------------------------------------------------------------------------------------------
function is_arm()
{
  is_arm32 || is_arm64
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
#----------------------------------------------------------------------------------------------------------------------
function download()
{
  local URL="$1"
  local FILE_NAME="$2"

  local WGET_ARGS=(--quiet)
  is_arm32 && WGET_ARGS+=(--no-check-certificate)

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
#----------------------------------------------------------------------------------------------------------------------
function extract()
{
  local FILE="${1}"
  log_info "Unpacking file: ${FILE}"
  tar xzf "${FILE}" --strip-components 1
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  build_and_install
#   DESCRIPTION:  Build and install the given package from the current directory using cmake.
#----------------------------------------------------------------------------------------------------------------------
function build_and_install()
{
  local PACKAGE_NAME="${1}"; shift
  local CMAKE_ARGS=(
    -Wno-dev
    -DCMAKE_BUILD_TYPE=Release
  )

  # shellcheck disable=SC2206
  CMAKE_ARGS+=( $@ )

  log_info "Building and installing ${PACKAGE_NAME} ..."
  log_debug "CMAKE_ARGS: ${CMAKE_ARGS[@]}"
  cmake ${CMAKE_ARGS[@]} .
  cmake --build . --target install --config Release
}
