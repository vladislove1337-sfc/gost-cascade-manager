#!/usr/bin/env bash
set -Eeuo pipefail
RAW_URL="https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh"
MENU_PATH="/usr/local/bin/gost-menu"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Запусти от root: sudo bash install.sh"
  exit 1
fi

apt-get update -y
apt-get install -y curl ca-certificates
curl -fL "$RAW_URL" -o "$MENU_PATH"
chmod +x "$MENU_PATH"
echo "Готово. Запуск: gost-menu"
gost-menu
