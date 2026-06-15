#!/usr/bin/env bash
set -Eeuo pipefail
URL="https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh"
TMP="/tmp/gost-menu.sh"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Запусти от root: sudo bash install.sh"
  exit 1
fi

apt-get update -y
apt-get install -y curl ca-certificates
curl -fsSL "$URL" -o "$TMP"
bash -n "$TMP"
install -m 0755 "$TMP" /usr/local/bin/gost-menu
echo "Готово. Запуск меню: gost-menu"
gost-menu
