#!/usr/bin/env bash

set -e
source "${SALT_RUNTIME_DIR}/functions.sh"

[[ ${DEBUG} == true ]] && set -x

case ${1} in
  app:start|app:init|app:gen-signed-keys)

    initialize_system

    case ${1} in
      app:start)
        echo "Starting salt-master..."
        exec sudo -HEu ${SALT_USER} salt-master
        ;;
      app:gen-signed-keys)
        shift 1
        gen_signed_keys ${1}
        ;;
    esac
    ;;
  app:help)
    echo "Available options:"
    echo "  app:start                         - Start salt-master service. (default)"
    echo "  app:gen-signed-keys <key_name>    - Create a master_sign key pair and its signature inside ${SALT_KEYS_DIR}/generated/"
    echo "  app:help                          - Displays this help."
    echo "  [command]                         - Execute the specified command, eg. bash."
    ;;
  *)
    exec "$@"
    ;;
esac
