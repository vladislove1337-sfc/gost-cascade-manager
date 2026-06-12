#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="gost-cascade"
SERVICE_NAME="gost"
BIN_PATH="/usr/local/bin/gost"
CONFIG_DIR="/etc/gost-cascade"
ENV_FILE="$CONFIG_DIR/gost.env"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
REPO_URL_DEFAULT="https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/gost-cascade-menu/main/gost-menu.sh"
SELF_PATH="/usr/local/bin/gost-menu"
LANGUAGE="en"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

need_root() { [[ $EUID -eq 0 ]] || { echo -e "${RED}Run as root: sudo bash $0${NC}"; exit 1; }; }

msg() {
  local key="$1"; shift || true
  case "$LANGUAGE:$key" in
    ru:title) echo -e "${BLUE}=== GOST Cascade Menu ===${NC}" ;;
    en:title) echo -e "${BLUE}=== GOST Cascade Menu ===${NC}" ;;
    ru:installed) echo -e "${GREEN}Готово.${NC}" ;;
    en:installed) echo -e "${GREEN}Done.${NC}" ;;
    ru:cancel) echo -e "${YELLOW}Отменено.${NC}" ;;
    en:cancel) echo -e "${YELLOW}Cancelled.${NC}" ;;
    *) echo "$key $*" ;;
  esac
}

pause() { read -rp "Press Enter / Нажми Enter..." _; }

ask() {
  local prompt="$1" default="${2:-}" value
  if [[ -n "$default" ]]; then
    read -rp "$prompt [$default]: " value
    echo "${value:-$default}"
  else
    read -rp "$prompt: " value
    echo "$value"
  fi
}

install_deps() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl wget tar gzip ca-certificates jq openssl
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv7*) echo "armv7" ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
}

latest_gost_version() {
  curl -fsSL "https://api.github.com/repos/go-gost/gost/releases/latest" | jq -r '.tag_name' | sed 's/^v//'
}

install_gost() {
  install_deps
  local version arch url tmp asset
  version="$(latest_gost_version)"
  arch="$(detect_arch)"
  asset="gost_${version}_linux_${arch}.tar.gz"
  url="https://github.com/go-gost/gost/releases/download/v${version}/${asset}"
  tmp="$(mktemp -d)"
  echo "Downloading GOST v${version} for linux_${arch}..."
  curl -fL "$url" -o "$tmp/gost.tar.gz"
  tar -xzf "$tmp/gost.tar.gz" -C "$tmp"
  find "$tmp" -type f -name gost -exec install -m 0755 {} "$BIN_PATH" \;
  rm -rf "$tmp"
  "$BIN_PATH" -V || true
}

write_service() {
  cat > "$SERVICE_FILE" <<EOF2
[Unit]
Description=GOST Cascade Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=$ENV_FILE
ExecStart=$BIN_PATH \$GOST_ARGS
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF2
  systemctl daemon-reload
  systemctl enable --now "$SERVICE_NAME"
}

make_config_dir() { mkdir -p "$CONFIG_DIR"; chmod 700 "$CONFIG_DIR"; }

random_string() { openssl rand -hex 12; }

install_foreign_relay_tls() {
  make_config_dir
  install_gost
  local user pass port
  user="$(ask 'User / Логин' "gost")"
  pass="$(ask 'Password / Пароль' "$(random_string)")"
  port="$(ask 'Port / Порт' "443")"
  cat > "$ENV_FILE" <<EOF2
GOST_MODE="foreign-relay-tls"
GOST_USER="$user"
GOST_PASS="$pass"
GOST_PORT="$port"
GOST_ARGS=-L "relay+tls://${user}:${pass}@:${port}"
EOF2
  chmod 600 "$ENV_FILE"
  write_service
  echo -e "${GREEN}Foreign relay+tls installed.${NC}"
  echo "Use on RU VPS: relay+tls://${user}:${pass}@FOREIGN_IP:${port}"
}

install_foreign_relay_wss_selfsigned() {
  make_config_dir
  install_gost
  local user pass port path cert key domain
  user="$(ask 'User / Логин' "gost")"
  pass="$(ask 'Password / Пароль' "$(random_string)")"
  port="$(ask 'Port / Порт' "443")"
  path="$(ask 'WSS path / Путь WSS' "/api/socket")"
  domain="$(ask 'Domain for self-signed cert CN / Домен для CN' "example.com")"
  cert="$CONFIG_DIR/cert.pem"; key="$CONFIG_DIR/key.pem"
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$key" -out "$cert" -days 3650 -subj "/CN=$domain" >/dev/null 2>&1
  chmod 600 "$key" "$cert"
  cat > "$ENV_FILE" <<EOF2
GOST_MODE="foreign-relay-wss-selfsigned"
GOST_USER="$user"
GOST_PASS="$pass"
GOST_PORT="$port"
GOST_PATH="$path"
GOST_ARGS=-L "relay+wss://${user}:${pass}@:${port}?path=${path}&certFile=${cert}&keyFile=${key}"
EOF2
  chmod 600 "$ENV_FILE"
  write_service
  echo -e "${GREEN}Foreign relay+wss installed with self-signed cert.${NC}"
  echo "Use on RU VPS: relay+wss://${user}:${pass}@FOREIGN_IP:${port}?path=${path}&secure=true"
}

install_ru_socks_to_foreign() {
  make_config_dir
  install_gost
  local listen_port foreign_url auth_user auth_pass
  listen_port="$(ask 'Local SOCKS5 port on RU / Локальный SOCKS5 порт на RU' "1080")"
  foreign_url="$(ask 'Foreign forward URL / URL иностранного узла, например relay+tls://user:pass@1.2.3.4:443')"
  auth_user="$(ask 'Local SOCKS user, empty = no auth / Локальный логин SOCKS, пусто = без авторизации' "")"
  if [[ -n "$auth_user" ]]; then
    auth_pass="$(ask 'Local SOCKS password / Локальный пароль SOCKS' "$(random_string)")"
    local_l="socks5://${auth_user}:${auth_pass}@:${listen_port}"
  else
    auth_pass=""
    local_l="socks5://:${listen_port}"
  fi
  cat > "$ENV_FILE" <<EOF2
GOST_MODE="ru-socks-chain"
GOST_LISTEN_PORT="$listen_port"
GOST_FOREIGN_URL="$foreign_url"
GOST_ARGS=-L "$local_l" -F "$foreign_url"
EOF2
  chmod 600 "$ENV_FILE"
  write_service
  echo -e "${GREEN}RU SOCKS chain installed.${NC}"
  echo "Client connects to RU_IP:${listen_port}"
}

show_status() {
  echo -e "${BLUE}GOST binary:${NC}"
  if command -v gost >/dev/null 2>&1; then gost -V || true; else echo "not installed"; fi
  echo
  echo -e "${BLUE}Config:${NC}"
  [[ -f "$ENV_FILE" ]] && sed 's/GOST_PASS=.*/GOST_PASS="***"/' "$ENV_FILE" || echo "no config"
  echo
  echo -e "${BLUE}Service:${NC}"
  systemctl --no-pager status "$SERVICE_NAME" || true
}

show_logs() { journalctl -u "$SERVICE_NAME" -n 120 --no-pager; }

restart_service() { systemctl restart "$SERVICE_NAME"; systemctl --no-pager status "$SERVICE_NAME" || true; }

stop_service() { systemctl stop "$SERVICE_NAME" || true; }

uninstall_all() {
  echo "This removes only GOST cascade files/service. Xray/sing-box will NOT be touched."
  read -rp "Type DELETE to continue / Введи DELETE для удаления: " confirm
  [[ "$confirm" == "DELETE" ]] || { msg cancel; return; }
  systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  rm -rf "$CONFIG_DIR"
  rm -f "$BIN_PATH"
  rm -f "$SELF_PATH"
  echo -e "${GREEN}Removed.${NC}"
}

install_menu_command() {
  install -m 0755 "$0" "$SELF_PATH"
  echo -e "${GREEN}Installed menu command: gost-menu${NC}"
}

self_update() {
  local url
  url="$(ask 'Raw GitHub URL for gost-menu.sh / Raw URL скрипта на GitHub' "$REPO_URL_DEFAULT")"
  curl -fL "$url" -o /tmp/gost-menu.new
  bash -n /tmp/gost-menu.new
  install -m 0755 /tmp/gost-menu.new "$SELF_PATH"
  echo -e "${GREEN}Updated. Run: gost-menu${NC}"
}

language_menu() {
  echo "1) Русский"
  echo "2) English"
  read -rp "> " l
  case "$l" in
    1) LANGUAGE="ru" ;;
    2) LANGUAGE="en" ;;
    *) LANGUAGE="ru" ;;
  esac
}

main_menu() {
  while true; do
    clear || true
    msg title
    echo "1) Install FOREIGN exit node: relay+tls"
    echo "2) Install FOREIGN exit node: relay+wss self-signed"
    echo "3) Install RU middle node: local SOCKS5 -> foreign"
    echo "4) Status / config"
    echo "5) Logs"
    echo "6) Restart service"
    echo "7) Stop service"
    echo "8) Install menu command: gost-menu"
    echo "9) Update this menu from GitHub raw URL"
    echo "10) Remove GOST cascade completely"
    echo "0) Exit"
    read -rp "> " choice
    case "$choice" in
      1) install_foreign_relay_tls; pause ;;
      2) install_foreign_relay_wss_selfsigned; pause ;;
      3) install_ru_socks_to_foreign; pause ;;
      4) show_status; pause ;;
      5) show_logs; pause ;;
      6) restart_service; pause ;;
      7) stop_service; pause ;;
      8) install_menu_command; pause ;;
      9) self_update; pause ;;
      10) uninstall_all; pause ;;
      0) exit 0 ;;
      *) echo "Wrong choice"; sleep 1 ;;
    esac
  done
}

need_root
language_menu
main_menu
