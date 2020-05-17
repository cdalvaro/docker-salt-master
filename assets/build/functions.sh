#!/usr/bin/env bash

set -e

# Execute a command as SALT_USER
function exec_as_salt()
{
  if [[ $(whoami) == "${SALT_USER}" ]]; then
    $@
  else
    sudo -HEu "${SALT_USER}" "$@"
  fi
}
