#!/usr/bin/env bash
# shellcheck disable=SC2016

echo "🧪 Running keys mount point tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

USER_UID=$(id -u)
USER_GID=$(id -g)

COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
# shellcheck source=tests/lib/common.sh
source "${COMMON_FILE}"
trap cleanup EXIT

KEYS_DIR="${SCRIPT_PATH}/keys"
SECRETS_DIR="${SCRIPT_PATH}/secrets"
WRONG_DIR="${SCRIPT_PATH}/wrong-keys"
SUPERVISORCTL=(supervisorctl -c /etc/supervisor/supervisord.conf)

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  reset_scenario
#   DESCRIPTION:  Remove the running container and wipe the keys directory so
#                 each scenario starts from a clean state.
#----------------------------------------------------------------------------------------------------------------------
function reset_scenario() {
  docker rm --force --volumes "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  sleep 3
  sudo rm -rf "${KEYS_DIR:?}"
  mkdir -p "${KEYS_DIR}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  gen_master_keypair
#   DESCRIPTION:  Generate a throw-away master key-pair (master.pem/master.pub)
#                 into the given directory, using the image's own salt-key.
#     ARGUMENTS:  $1 -> Destination directory.
#----------------------------------------------------------------------------------------------------------------------
function gen_master_keypair() {
  local dest_dir="$1"
  mkdir -p "${dest_dir}"
  # Salt 3008 writes the pair through the localfs_key cache, which drops to
  # the in-image salt user (via the loader's _run_as), not root. The dir is
  # created on the host by the CI runner uid, so the salt user cannot write
  # into the bind mount (PermissionError on /keys/tmpXXXX). Make it writable
  # for the run via the entrypoint `exec "$@"` passthrough, then hand the
  # generated key-pair back to the runner user. stderr is kept visible on
  # purpose so a future failure is diagnosable.
  chmod 0777 "${dest_dir}"
  docker run --rm \
    --volume "${dest_dir}":/keys \
    --platform "${PLATFORM}" "${IMAGE_NAME}" \
    salt-key --gen-keys master --gen-keys-dir /keys >/dev/null
  sudo chown -R "${USER_UID}:${USER_GID}" "${dest_dir}"
  [[ -f "${dest_dir}/master.pem" && -f "${dest_dir}/master.pub" ]]
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  assert_master_running
#   DESCRIPTION:  Assert salt-master is in the RUNNING state under supervisord.
#     ARGUMENTS:  $1 -> Assertion message.
#----------------------------------------------------------------------------------------------------------------------
function assert_master_running() {
  local message="$1"
  local status=
  status="$(docker-exec "${SUPERVISORCTL[@]}" status salt-master 2>/dev/null || true)"
  if [[ "${status}" == *RUNNING* ]]; then
    ok "${message}"
  else
    error "${message} (supervisor status: ${status:-unknown})"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  assert_regular_file
#   DESCRIPTION:  Assert the given path is a regular file and NOT a symlink
#                 (the core Salt 3008.0 localfs_key requirement).
#     ARGUMENTS:  $1 -> Path. $2 -> Assertion message.
#----------------------------------------------------------------------------------------------------------------------
function assert_regular_file() {
  local path="$1"
  local message="$2"
  if [[ -f "${path}" && ! -L "${path}" ]]; then
    ok "${message}"
  else
    error "${message} ('${path}' missing or is a symlink)"
  fi
}

# ---------------------------------------------------------------------------------------------------------------------
# Scenario 1: no secrets, full keys volume mounted (generate path, unchanged
#             behaviour). Also asserts the generated keys are REGULAR FILES.
# ---------------------------------------------------------------------------------------------------------------------
echo "==> [1/6] Generated keys on a mounted keys volume ..."
reset_scenario
start_container_and_wait \
  --env SALT_MASTER_SIGN_PUBKEY=True \
  --volume "${KEYS_DIR}":/home/salt/data/keys || error "container started"
ok "container started"
assert_master_running "salt-master running (generated keys)"

echo "==> Checking keys permissions ..."
KEYS_PERMISSIONS="$(find "${KEYS_DIR}" -type f -exec stat -c "%n %a %u:%g" {} \; | sort)"
EXPECTED_PERMISSIONS=$(
  cat <<EOF
${KEYS_DIR}/master.pem 400 ${USER_UID}:${USER_GID}
${KEYS_DIR}/master.pub 644 ${USER_UID}:${USER_GID}
${KEYS_DIR}/master_pubkey_signature 644 ${USER_UID}:${USER_GID}
${KEYS_DIR}/master_sign.pem 400 ${USER_UID}:${USER_GID}
${KEYS_DIR}/master_sign.pub 644 ${USER_UID}:${USER_GID}
EOF
)
check_equal "${KEYS_PERMISSIONS}" "${EXPECTED_PERMISSIONS}" "keys permissions"

# Salt 3008.0: keys must be regular files, never symlinks.
assert_regular_file "${KEYS_DIR}/master.pem" "master.pem is a regular file"
assert_regular_file "${KEYS_DIR}/master_sign.pem" "master_sign.pem is a regular file"
assert_log_not_contains "is not a valid key path" "no SaltCacheError in log"

# Test app:gen-signed-keys
echo "==> Creating signed keys with app:gen-signed-keys ..."
GEN_SIGNED_KEYS_OUTPUT=$(docker run --rm \
  --env SALT_MASTER_SIGN_PUBKEY=True \
  --env PUID="${USER_UID}" --env PGID="${USER_GID}" \
  --volume "${KEYS_DIR}":/home/salt/data/keys \
  --platform "${PLATFORM}" "${IMAGE_NAME}" app:gen-signed-keys)
RETURN_CODE=$?
echo "${GEN_SIGNED_KEYS_OUTPUT}"

[[ ${RETURN_CODE} == 0 ]] || error "app:gen-signed-keys"
ok "app:gen-signed-keys"

# Check generated keys directory
EXPECTED_DIRECTORY=$(find "${KEYS_DIR}"/generated -type d | tail -n1)
SIGNED_KEYS_DIRECTORY="${KEYS_DIR}/$(echo "${GEN_SIGNED_KEYS_OUTPUT}" | tail -n1 | sed -E 's/.* //')"
check_equal "${SIGNED_KEYS_DIRECTORY}" "${EXPECTED_DIRECTORY}" "generated signed keys directory"

# Check signed keys permissions
echo "==> Checking signed keys permissions ..."
KEYS_PERMISSIONS="$(find "${SIGNED_KEYS_DIRECTORY}" -type f -exec stat -c "%n %a %u:%g" {} \; | sort)"
EXPECTED_PERMISSIONS=$(
  cat <<EOF
${SIGNED_KEYS_DIRECTORY}/master_pubkey_signature 644 ${USER_UID}:${USER_GID}
${SIGNED_KEYS_DIRECTORY}/master_sign.pem 400 ${USER_UID}:${USER_GID}
${SIGNED_KEYS_DIRECTORY}/master_sign.pub 644 ${USER_UID}:${USER_GID}
EOF
)
check_equal "${KEYS_PERMISSIONS}" "${EXPECTED_PERMISSIONS}" "keys permissions"

# ---------------------------------------------------------------------------------------------------------------------
# Prepare a master key-pair to be used as a Docker "secret" for the next
# scenarios (bind-mounted at /run/secrets, exposed via SALT_MASTER_KEY_FILE).
# ---------------------------------------------------------------------------------------------------------------------
echo "==> Generating a master key-pair to be used as a secret ..."
rm -rf "${SECRETS_DIR}" "${WRONG_DIR}"
gen_master_keypair "${SECRETS_DIR}" || error "secret key-pair generated"
ok "secret key-pair generated"

SECRET_ENV=(--env SALT_MASTER_KEY_FILE=/run/secrets/master
  --volume "${SECRETS_DIR}":/run/secrets:ro)

# ---------------------------------------------------------------------------------------------------------------------
# Scenario 2: secret provided + full keys volume mounted, no pre-existing key
#             (the "careless full mount" case). The secret must be COPIED in as
#             a regular file and salt-master must start.
# ---------------------------------------------------------------------------------------------------------------------
echo "==> [2/6] Secret provided, fresh keys volume ..."
reset_scenario
start_container_and_wait \
  "${SECRET_ENV[@]}" \
  --volume "${KEYS_DIR}":/home/salt/data/keys || error "container started (secret, fresh)"
assert_master_running "salt-master running (secret, fresh)"
assert_regular_file "${KEYS_DIR}/master.pem" "secret master.pem copied as a regular file"
if cmp -s "${SECRETS_DIR}/master.pem" "${KEYS_DIR}/master.pem" &&
  cmp -s "${SECRETS_DIR}/master.pub" "${KEYS_DIR}/master.pub"; then
  ok "copied keys match the secret"
else
  error "copied keys match the secret"
fi
assert_log_not_contains "is not a valid key path" "no SaltCacheError (secret, fresh)"

# ---------------------------------------------------------------------------------------------------------------------
# Scenario 3: secret provided + pre-existing legacy SYMLINKS (<3008 layout /
#             upgrade). The symlinks must be replaced by a copy of the secret.
# ---------------------------------------------------------------------------------------------------------------------
echo "==> [3/6] Secret provided, legacy symlinked keys (migration) ..."
reset_scenario
ln -s /run/secrets/master.pem "${KEYS_DIR}/master.pem"
ln -s /run/secrets/master.pub "${KEYS_DIR}/master.pub"
start_container_and_wait \
  "${SECRET_ENV[@]}" \
  --volume "${KEYS_DIR}":/home/salt/data/keys || error "container started (secret, symlink)"
assert_master_running "salt-master running (secret, symlink migration)"
assert_regular_file "${KEYS_DIR}/master.pem" "legacy symlink replaced by a regular file"
if cmp -s "${SECRETS_DIR}/master.pem" "${KEYS_DIR}/master.pem"; then
  ok "replaced key matches the secret"
else
  error "replaced key matches the secret"
fi
assert_log_contains "Replacing legacy symlinked master keys" "migration logged"
assert_log_not_contains "is not a valid key path" "no SaltCacheError (secret, symlink)"

# ---------------------------------------------------------------------------------------------------------------------
# Scenario 4: secret provided + pre-existing regular file that MATCHES the
#             secret. It must be kept as-is, no warning.
# ---------------------------------------------------------------------------------------------------------------------
echo "==> [4/6] Secret provided, matching regular keys ..."
reset_scenario
cp "${SECRETS_DIR}/master.pem" "${KEYS_DIR}/master.pem"
cp "${SECRETS_DIR}/master.pub" "${KEYS_DIR}/master.pub"
start_container_and_wait \
  "${SECRET_ENV[@]}" \
  --volume "${KEYS_DIR}":/home/salt/data/keys || error "container started (secret, match)"
assert_master_running "salt-master running (secret, matching keys)"
assert_regular_file "${KEYS_DIR}/master.pem" "matching master.pem kept as a regular file"
assert_log_contains "match the provided secret" "match logged (no warning)"
assert_log_not_contains "is not a valid key path" "no SaltCacheError (secret, match)"

# ---------------------------------------------------------------------------------------------------------------------
# Scenario 5: secret provided + pre-existing regular file that does NOT match
#             the secret. The on-disk key must win, the secret is ignored, a
#             WARNING is logged and the container still starts (non-fatal).
# ---------------------------------------------------------------------------------------------------------------------
echo "==> [5/6] Secret provided, mismatching regular keys (warn, on-disk wins) ..."
reset_scenario
gen_master_keypair "${WRONG_DIR}" || error "mismatching key-pair generated"
cp "${WRONG_DIR}/master.pem" "${KEYS_DIR}/master.pem"
cp "${WRONG_DIR}/master.pub" "${KEYS_DIR}/master.pub"
start_container_and_wait \
  "${SECRET_ENV[@]}" \
  --volume "${KEYS_DIR}":/home/salt/data/keys || error "container started (secret, mismatch)"
assert_master_running "salt-master running (secret, mismatch -> on-disk key)"
if cmp -s "${WRONG_DIR}/master.pem" "${KEYS_DIR}/master.pem"; then
  ok "on-disk key preserved (secret ignored)"
else
  error "on-disk key preserved (secret ignored)"
fi
if cmp -s "${SECRETS_DIR}/master.pem" "${KEYS_DIR}/master.pem"; then
  error "secret must NOT overwrite a mismatching on-disk key"
else
  ok "secret did not overwrite the on-disk key"
fi
assert_log_contains "do NOT match it" "mismatch warning logged"
assert_log_not_contains "is not a valid key path" "no SaltCacheError (secret, mismatch)"

# ---------------------------------------------------------------------------------------------------------------------
# Scenario 6: secret provided + pre-existing regular master.pem that does NOT
#             match the secret, but WITHOUT master.pub. The decision must be
#             governed by the PRIVATE key alone: the on-disk private key must
#             NOT be overwritten just because the public key is missing, and
#             salt-master regenerates master.pub from it on start-up.
# ---------------------------------------------------------------------------------------------------------------------
echo "==> [6/6] Secret provided, regular master.pem without master.pub (private key preserved) ..."
reset_scenario
gen_master_keypair "${WRONG_DIR}" || error "mismatching key-pair generated"
cp "${WRONG_DIR}/master.pem" "${KEYS_DIR}/master.pem" # private key only, no master.pub
start_container_and_wait \
  "${SECRET_ENV[@]}" \
  --volume "${KEYS_DIR}":/home/salt/data/keys || error "container started (secret, pem-only)"
assert_master_running "salt-master running (pem-only, on-disk key wins)"
if cmp -s "${WRONG_DIR}/master.pem" "${KEYS_DIR}/master.pem"; then
  ok "on-disk private key preserved (not overwritten by the secret)"
else
  error "on-disk private key preserved (not overwritten by the secret)"
fi
if cmp -s "${SECRETS_DIR}/master.pem" "${KEYS_DIR}/master.pem"; then
  error "secret must NOT overwrite a regular on-disk private key"
else
  ok "secret did not overwrite the on-disk private key"
fi
assert_regular_file "${KEYS_DIR}/master.pub" "master.pub regenerated as a regular file"
assert_log_contains "do NOT match it" "mismatch warning logged (pem-only)"
assert_log_not_contains "is not a valid key path" "no SaltCacheError (secret, pem-only)"

# Cleanup scenario fixtures (container is removed by the EXIT trap).
rm -rf "${SECRETS_DIR}" "${WRONG_DIR}"

ok "All keys mount point scenarios passed"
