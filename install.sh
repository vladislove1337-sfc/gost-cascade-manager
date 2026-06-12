#!/usr/bin/env bash
set -e
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi
bash ./gost-menu.sh
