#!/usr/bin/env bash

set -e
source "${SALT_RUNTIME_DIR}/functions.sh"

[[ ${DEBUG} == true ]] && set -x

case ${1} in
  app:start)

configure_salt_master

    case ${1} in
      app:start)
        copy_minion_keys
echo "Starting salt-master..."
exec salt-master
        ;;
    esac
    ;;
  app:help)
    echo "Available options:"
    echo "  app:start       - Start salt-master service. (default)"
    echo "  app:help        - Displays this help."
    echo "  [command]       - Execute the specified command, eg. bash."
    ;;
  *)
    exec "$@"
    ;;
esac
