#!/bin/bash

set -e
set -o pipefail

source "${SALT_RUNTIME_DIR}/functions.sh"

[[ "${DEBUG}" == true ]] && set -x

case "${1}" in
  app:start|app:gen-signed-keys)

    initialize_system

    case "${1}" in
      app:start)
        echo "Starting supervisord ..."
        exec /usr/bin/supervisord -nc /etc/supervisor/supervisord.conf
        ;;
      app:gen-signed-keys)
        shift 1
        gen_signed_keys "${1}"
        ;;
    esac
    ;;
  app:restart)
    shift 1
    case "${1}" in
      salt-master|salt-api)
        echo "Restarting ${1} service ..."
        exec pkill "${1}"
        ;;
      *)
        log_error "Unable to restart ${1} serice. Service is unknown"
        exit 1
        ;;
    esac
    ;;
  app:reload-3rd-formulas)
    configure_salt_formulas
    exec "$0" app:restart salt-master
    ;;
  app:help)
    echo "Available options:"
    echo "  app:start                         - Start configured services. (default)"
    echo "  app:restart                       - Restart the specified service on a running container. Choices: salt-master, salt-api"
    echo "  app:reload-3rd-formulas           - Update master.yml with available 3rd-formulas and restart salt-master service"
    echo "  app:gen-signed-keys <key_name>    - Create a master_sign key pair and its signature inside ${SALT_KEYS_DIR}/generated/"
    echo "  app:help                          - Displays this help."
    echo "  [command]                         - Execute the specified command, eg. bash."
    ;;
  *)
    exec "$@"
    ;;
esac
