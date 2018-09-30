#!/usr/bin/env bash

set -e
source "${SALT_RUNTIME_DIR}/functions.sh"

[[ ${DEBUG} == true ]] && set -x

case ${1} in
  app:start|app:init|app:gen-signed-keys)

    configure_salt_master

    case ${1} in
      app:start)
        setup_keys
        echo "Starting salt-master..."
        exec salt-master
        ;;
      app:init)
        setup_keys
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
    echo "  app:init                          - Setup salt-master without launching the service."
    echo "  app:gen-signed-keys <key_name>    - Create a master_sign key pair and its signature inside ${SALT_KEYS_DIR}/generated/"
    echo "  app:help                          - Displays this help."
    echo "  [command]                         - Execute the specified command, eg. bash."
    ;;
  *)
    exec "$@"
    ;;
esac
