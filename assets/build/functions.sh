#!/usr/bin/env bash

set -e

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_debug
#   DESCRIPTION:  Echo debug information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_debug() {
  if [[ "${DEBUG}" == 'true' || "${ECHO_DEBUG}" == 'true' ]]; then
    echo " *  DEBUG: $*"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_info
#   DESCRIPTION:  Echo information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_info() {
  echo " *  INFO: $*"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_warn
#   DESCRIPTION:  Echo warning information to stdout.
#----------------------------------------------------------------------------------------------------------------------
function log_warn() {
  echo " *  WARN: $*"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  log_error
#   DESCRIPTION:  Echo errors to stderr.
#----------------------------------------------------------------------------------------------------------------------
function log_error()
{
  (>&2 echo " *  ERROR: $*")
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

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_libssh2
#   DESCRIPTION:  Install libssh2 library.
#----------------------------------------------------------------------------------------------------------------------
function install_libssh2()
{
  local LIBSSH2_VERSION=1.10.0
  local LIBSSH2_URL="https://github.com/libssh2/libssh2/releases/download/libssh2-${LIBSSH2_VERSION}/libssh2-${LIBSSH2_VERSION}.tar.gz"
  local FILE_NAME="libssh2-${LIBSSH2_VERSION}.tar.gz"
  local SHA256_SUM='2d64e90f3ded394b91d3a2e774ca203a4179f69aebee03003e5a6fa621e41d51'

  local CURRENT_DIR="$(pwd)"
  local WORK_DIR="$(mktemp -d)" && cd "${WORK_DIR}"

  download "${LIBSSH2_URL}" "${FILE_NAME}"
  check_sha256 "${FILE_NAME}" "${SHA256_SUM}"
  extract "${FILE_NAME}"

  _OPTS=(
    -DLINT=OFF
    -DBUILD_SHARED_LIBS=ON
    -DCRYPTO_BACKEND=OpenSSL
    -DENABLE_ZLIB_COMPRESSION=ON
    -DENABLE_DEBUG_LOGGING=OFF
    -DCLEAR_MEMORY=ON
  )

  build_and_install "libssh2 v${LIBSSH2_VERSION}" ${_OPTS[@]}

  cd "${CURRENT_DIR}"
  rm -rf "${WORK_DIR}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_libgit2
#   DESCRIPTION:  Install libgit2 library.
#----------------------------------------------------------------------------------------------------------------------
function install_libgit2()
{
  local LIBGIT2_VERSION=1.3.0
  local LIBGIT2_URL="https://github.com/libgit2/libgit2/archive/refs/tags/v${LIBGIT2_VERSION}.tar.gz"
  local FILE_NAME="libgit2-${LIBGIT2_VERSION}.tar.gz"
  local SHA256_SUM='192eeff84596ff09efb6b01835a066f2df7cd7985e0991c79595688e6b36444e'

  local CURRENT_DIR="$(pwd)"
  local WORK_DIR="$(mktemp -d)" && cd "${WORK_DIR}"

  download "${LIBGIT2_URL}" "${FILE_NAME}"
  check_sha256 "${FILE_NAME}" "${SHA256_SUM}"
  extract "${FILE_NAME}"

  build_and_install "libgit2 v${LIBGIT2_VERSION}" -DBUILD_CLAR=OFF

  cd "${CURRENT_DIR}"
  rm -rf "${WORK_DIR}"
}
