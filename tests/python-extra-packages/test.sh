#!/usr/bin/env bash

echo "🧪 Running python extra packages tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
# shellcheck source=tests/lib/common.sh
source "${COMMON_FILE}"
trap cleanup EXIT

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  pip_pkg_version
#   DESCRIPTION:  Check whether a pip package is installed or not.
#                 If installed, return the version, otherwise return null.
#----------------------------------------------------------------------------------------------------------------------
function pip_pkg_version() {
  local PKG_NAME="$1"
  local JQ_OPTIONS=(--monochrome-output --raw-output --arg pkg "${PKG_NAME}")

  PKGS_LIST="$(docker-exec salt-call --local --out=json pip.list)"
  PKG_INSTALLED="$(echo -n "${PKGS_LIST}" | jq "${JQ_OPTIONS[@]}" '.local | has($pkg)')"

  if [[ "${PKG_INSTALLED,,}" != "true" ]]; then
    echo -n "null"
    return 1
  fi

  echo -n "${PKGS_LIST}" | jq "${JQ_OPTIONS[@]}" --exit-status '.local | .[$pkg]'
}

# requirements.txt file
PYTHON_TEST_PACKAGE1_NAME="docker"
PYTHON_TEST_PACKAGE1_VERSION="6.1.3"
PYTHON_TEST_PACKAGE2_NAME="redis"
PYTHON_TEST_PACKAGE3_NAME="GitPython"
REQUIREMENTS_FILE="${SCRIPT_PATH}/requirements.txt"
cat >"${REQUIREMENTS_FILE}" <<EOF
${PYTHON_TEST_PACKAGE1_NAME}==${PYTHON_TEST_PACKAGE1_VERSION}
${PYTHON_TEST_PACKAGE2_NAME}
EOF

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with PYTHON_PACKAGES_FILE ..."
start_container_and_wait \
  --volume "${REQUIREMENTS_FILE}:/home/salt/data/other/requirements.txt" \
  --env PYTHON_PACKAGES_FILE=/home/salt/data/other/requirements.txt ||
  error "container started"
ok "container started"

# Test salt pip installed packages
echo "==> Checking salt-pip packages (requirements.txt) ..."
check_equal "$(pip_pkg_version "${PYTHON_TEST_PACKAGE1_NAME}")" "${PYTHON_TEST_PACKAGE1_VERSION}" \
  "python package ${PYTHON_TEST_PACKAGE1_NAME} is installed"
[[ "$(pip_pkg_version "${PYTHON_TEST_PACKAGE2_NAME}")" != "null" ]] || error "python package ${PYTHON_TEST_PACKAGE2_NAME} is not installed"
ok "python package ${PYTHON_TEST_PACKAGE2_NAME} is installed"

# Stop and start with salt-api pass via file
echo "==> Stopping previous container ..."
cleanup || error "Unable to stop previour container"

echo "==> Starting docker-salt-master (${PLATFORM}) with PYTHON_PACKAGES ..."
start_container_and_wait \
  --env PYTHON_PACKAGES="${PYTHON_TEST_PACKAGE1_NAME}==${PYTHON_TEST_PACKAGE1_VERSION}" ||
  error "container started"
ok "container started"

# Test salt pip installed packages
echo "==> Checking salt-pip packages (environment) ..."
check_equal "$(pip_pkg_version "${PYTHON_TEST_PACKAGE1_NAME}")" "${PYTHON_TEST_PACKAGE1_VERSION}" \
  "python package ${PYTHON_TEST_PACKAGE1_NAME} is installed"

# Stop and start with salt-api pass via file
echo "==> Stopping previous container ..."
cleanup || error "Unable to stop previour container"

echo "==> Starting docker-salt-master (${PLATFORM}) with PYTHON_PACKAGES_FILE and PYTHON_PACKAGES ..."
start_container_and_wait \
  --volume "${REQUIREMENTS_FILE}:/home/salt/data/other/requirements.txt" \
  --env PYTHON_PACKAGES_FILE=/home/salt/data/other/requirements.txt \
  --env PYTHON_PACKAGES="${PYTHON_TEST_PACKAGE3_NAME}" ||
  error "container started"
ok "container started"

# Test salt pip installed packages
echo "==> Checking salt-pip packages (environment) ..."
check_equal "$(pip_pkg_version "${PYTHON_TEST_PACKAGE1_NAME}")" "${PYTHON_TEST_PACKAGE1_VERSION}" \
  "python package ${PYTHON_TEST_PACKAGE1_NAME} is installed"
[[ "$(pip_pkg_version "${PYTHON_TEST_PACKAGE2_NAME}")" != "null" ]] || error "python package ${PYTHON_TEST_PACKAGE2_NAME} is not installed"
ok "python package ${PYTHON_TEST_PACKAGE2_NAME} is installed"
[[ "$(pip_pkg_version "${PYTHON_TEST_PACKAGE3_NAME}")" == "null" ]] || error "python package ${PYTHON_TEST_PACKAGE3_NAME} is installed"
ok "python package ${PYTHON_TEST_PACKAGE3_NAME} is not installed"
