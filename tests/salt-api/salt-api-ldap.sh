#!/usr/bin/env bash

echo "🧪 Running salt-api LDAP integration tests ..."

# https://stackoverflow.com/a/4774063/3398062
# shellcheck disable=SC2164
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

COMMON_FILE="${SCRIPT_PATH}/../lib/common.sh"
# shellcheck source=tests/lib/common.sh
source "${COMMON_FILE}"

function cleanup_all()
{
  echo "🧹 Cleaning up openldap container ..."
  docker container rm --force --volumes "openldap" > /dev/null
  sleep 5

  cleanup
}

trap cleanup_all EXIT

export SALTAPI_URL="https://localhost:8000/"
export SALTAPI_ADMIN_USER=admin
export SALTAPI_ADMIN_PASS=admin
export SALTAPI_USER=readonly
export SALTAPI_PASS=readonly
export SALTAPI_GROUP=saltadmins
export SALTAPI_EAUTH=ldap

# Create configuration files
echo "==> Creating salt-api configuration file ..."
mkdir -p "${SCRIPT_PATH}/config"
cat > "${SCRIPT_PATH}/config/salt-api.conf" <<EOF
auth.ldap.uri: ldap://openldap:389
auth.ldap.anon: False
auth.ldap.groupou: ''
auth.ldap.groupattribute: 'memberUid'
auth.ldap.groupclass: 'posixGroup'
auth.ldap.basedn: 'dc=example,dc=org'
auth.ldap.binddn: 'cn={{ username }},dc=example,dc=org'

# Breaking change from 3006
# https://docs.saltproject.io/en/latest/topics/netapi/netapi-enable-clients.html
netapi_enable_clients:
  - local
  - local_async
  - local_batch
  - local_subset
  - runner
  - runner_async

external_auth:
  ${SALTAPI_EAUTH}:
    ${SALTAPI_ADMIN_USER}:
      - .*
      - '@runner'
      - '@wheel'
      - '@jobs'
    ${SALTAPI_GROUP}%:
      - .*
      - '@runner'
      - '@wheel'
      - '@jobs'
EOF
ok "salt-api config created"

mkdir -p "${SCRIPT_PATH}/ldif"
cat > "${SCRIPT_PATH}/ldif/admingroup.ldif" <<EOF
# Add to 'admins' group
dn: cn=${SALTAPI_GROUP},dc=example,dc=org
objectClass: top
objectClass: posixGroup
cn: ${SALTAPI_GROUP}
memberUid: ${SALTAPI_USER}
gidNumber: 1000
EOF


# configure docker network to allow containers to talk to each other
docker network create ldap-test 2>/dev/null || true

# Run openldap instance
# Accounts: admin:admin and readonly:readonly
docker run \
  --name openldap \
  --network ldap-test \
  --publish 389:389 \
  --volume "${SCRIPT_PATH}/ldif:/ldif" \
  --env LDAP_READONLY_USER=true \
  --detach \
  osixia/openldap
sleep 10

# Add user and group
docker exec openldap ldapadd -x -H ldap://localhost:389 -D "cn=admin,dc=example,dc=org" -w admin -f "/ldif/admingroup.ldif"

# Run test instance
echo "==> Starting docker-salt-master (${PLATFORM}) with salt-api config and no api user ..."
start_container_and_wait \
  --network ldap-test \
  --publish 8000:8000 \
  --env SALT_API_ENABLED=True \
  --env SALT_API_USER="" \
|| error "container started"
ok "container started"

# Test salt-api authentication as 'admin' user
echo "==> Getting salt-api ${SALTAPI_ADMIN_USER} token ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL%/}/login" \
  -H "Accept: application/x-yaml" \
  -d username="${SALTAPI_ADMIN_USER}" \
  -d password="${SALTAPI_ADMIN_PASS}" \
  -d eauth="${SALTAPI_EAUTH}")"
echo "${CURL_OUTPUT}"

SALTAPI_TOKEN="$(echo -n "${CURL_OUTPUT}" | grep -Ei 'token: ([^\s]+)' | awk '{print $2}')"
[ -n "${SALTAPI_TOKEN}" ] || error "salt-api token"
ok "salt-api ${SALTAPI_ADMIN_USER} token"

# Test salt-api permissions as a user
echo "==> Testing curl 'user' command ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL}" \
  -H "Accept: application/x-yaml" \
  -H "X-Auth-Token: ${SALTAPI_TOKEN}" \
  -d client=runner \
  -d tgt='*' \
  -d fun=test.stream)"
echo "${CURL_OUTPUT}"

echo -n "${CURL_OUTPUT}" | grep -i true || error "curl command"
ok "curl ${SALTAPI_ADMIN_USER} user command"

# Test salt-api authentication as 'readonly' user
echo "==> Getting salt-api ${SALTAPI_USER} token ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL%/}/login" \
  -H "Accept: application/x-yaml" \
  -d username="${SALTAPI_USER}" \
  -d password="${SALTAPI_PASS}" \
  -d eauth="${SALTAPI_EAUTH}")"
echo "${CURL_OUTPUT}"

SALTAPI_TOKEN="$(echo -n "${CURL_OUTPUT}" | grep -Ei 'token: ([^\s]+)' | awk '{print $2}')"
[ -n "${SALTAPI_TOKEN}" ] || error "salt-api token"
ok "salt-api ${SALTAPI_USER} token"

# Test salt-api permissions as group
echo "==> Testing curl 'group' command ..."
CURL_OUTPUT="$(curl -sSk "${SALTAPI_URL}" \
  -H "Accept: application/x-yaml" \
  -H "X-Auth-Token: ${SALTAPI_TOKEN}" \
  -d client=runner \
  -d tgt='*' \
  -d fun=test.stream)"
echo "${CURL_OUTPUT}"

echo -n "${CURL_OUTPUT}" | grep -i true || error "curl command"
ok "curl ${SALTAPI_GROUP} group command"
