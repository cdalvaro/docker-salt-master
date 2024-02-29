#!/usr/bin/env bash
# shellcheck disable=SC2016

echo "🧪 Running keys mount point tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

USER_UID=$(id -u)
USER_GID=$(id -g)

# shellcheck source=assets/build/functions.sh
COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
source "${COMMON_FILE}"
trap cleanup EXIT

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) ..."
mkdir keys
start_container_and_wait \
  --env SALT_MASTER_SIGN_PUBKEY=True \
  --volume "$(pwd)/keys":/home/salt/data/keys || error "container started"
ok "container started"

# Test salt-master is running
echo "==> Executing healthcheck ..."
docker-exec /usr/local/sbin/healthcheck || error "healthcheck"
ok "healthcheck"

# Test keys permissions
echo "==> Checking keys permissions ..."
KEYS_PERMISSIONS="$(find keys -type f -exec stat -c "%n %a %u:%g" {} \; | sort)"
EXPECTED_PERMISSIONS=$(cat <<EOF
keys/master.pem 600 ${USER_UID}:${USER_GID}
keys/master.pub 644 ${USER_UID}:${USER_GID}
keys/master_pubkey_signature 644 ${USER_UID}:${USER_GID}
keys/master_sign.pem 600 ${USER_UID}:${USER_GID}
keys/master_sign.pub 644 ${USER_UID}:${USER_GID}
EOF
)
check_equal "${KEYS_PERMISSIONS}" "${EXPECTED_PERMISSIONS}" "keys permissions"

# Test app:gen-signed-keys
echo "==> Creating signed keys with app:gen-signed-keys ..."
GEN_SIGNED_KEYS_OUTPUT=$(docker run --rm \
  --env SALT_MASTER_SIGN_PUBKEY=True \
  --env PUID="${USER_UID}" --env PGID="${USER_GID}" \
  --volume "$(pwd)/keys":/home/salt/data/keys \
  --platform "${PLATFORM}" "${IMAGE_NAME}" app:gen-signed-keys)
RETURN_CODE=$?
echo "${GEN_SIGNED_KEYS_OUTPUT}"

[[ ${RETURN_CODE} == 0 ]] || error "app:gen-signed-keys"
ok "app:gen-signed-keys"

# Check generated keys directory
EXPECTED_DIRECTORY=$(find keys/generated -type d | tail -n1)
SIGNED_KEYS_DIRECTORY="keys/$(echo "${GEN_SIGNED_KEYS_OUTPUT}" | tail -n1 | sed -E 's/.* //')"
check_equal "${SIGNED_KEYS_DIRECTORY}" "${EXPECTED_DIRECTORY}" "generated signed keys directory"

# Check signed keys permissions
echo "==> Checking signed keys permissions ..."
KEYS_PERMISSIONS="$(find "${SIGNED_KEYS_DIRECTORY}" -type f -exec stat -c "%n %a %u:%g" {} \; | sort)"
EXPECTED_PERMISSIONS=$(cat <<EOF
${SIGNED_KEYS_DIRECTORY}/master_pubkey_signature 600 ${USER_UID}:${USER_GID}
${SIGNED_KEYS_DIRECTORY}/master_sign.pem 600 ${USER_UID}:${USER_GID}
${SIGNED_KEYS_DIRECTORY}/master_sign.pub 600 ${USER_UID}:${USER_GID}
EOF
)
check_equal "${KEYS_PERMISSIONS}" "${EXPECTED_PERMISSIONS}" "keys permissions"
