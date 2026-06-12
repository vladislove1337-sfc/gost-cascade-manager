#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="gost-cascade-manager"
SERVICE_NAME="gost"
BIN_PATH="/usr/local/bin/gost"
MENU_PATH="/usr/local/bin/gost-menu"
CONFIG_DIR="/etc/gost-cascade"
CONFIG_FILE="$CONFIG_DIR/config.env"
LANG_FILE="$CONFIG_DIR/lang"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
RAW_URL="https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LANGUAGE="ru"

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo -e "${RED}Запусти от root: sudo bash gost-menu.sh${NC}"
    exit 1
  fi
}

make_config_dir() {
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
}

load_language() {
  if [[ -f "$LANG_FILE" ]]; then
    LANGUAGE="$(cat "$LANG_FILE" 2>/dev/null || echo ru)"
  else
    LANGUAGE="ru"
  fi
}

save_language() {
  make_config_dir
  echo "$LANGUAGE" > "$LANG_FILE"
}

tr() {
  local key="$1"
  case "$LANGUAGE:$key" in
    ru:title) echo "=== GOST Cascade Manager ===" ;;
    en:title) echo "=== GOST Cascade Manager ===" ;;
    ru:pause) echo "Нажми Enter, чтобы продолжить..." ;;
    en:pause) echo "Press Enter to continue..." ;;
    ru:done) echo "Готово." ;;
    en:done) echo "Done." ;;
    ru:cancel) echo "Отменено." ;;
    en:cancel) echo "Cancelled." ;;
    ru:wrong) echo "Неверный пункт меню." ;;
    en:wrong) echo "Wrong menu item." ;;
    *) echo "$key" ;;
  esac
}

ok() { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
err() { echo -e "${RED}$*${NC}"; }
info() { echo -e "${BLUE}$*${NC}"; }

pause() {
  local p
  p="$(tr pause)"
  read -rp "$p" _ || true
}

ask() {
  local prompt="$1"
  local default="${2:-}"
  local value
  if [[ -n "$default" ]]; then
    read -rp "$prompt [$default]: " value
    echo "${value:-$default}"
  else
    read -rp "$prompt: " value
    echo "$value"
  fi
}

random_string() {
  openssl rand -hex 12
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
    *) err "Неподдерживаемая архитектура: $arch"; exit 1 ;;
  esac
}

latest_gost_version() {
  local version
  version="$(curl -fsSL https://api.github.com/repos/go-gost/gost/releases/latest | jq -r '.tag_name' | sed 's/^v//' || true)"
  if [[ -z "$version" || "$version" == "null" ]]; then
    version="3.2.3"
  fi
  echo "$version"
}

install_gost_binary() {
  install_deps
  local version arch url tmp
  version="$(latest_gost_version)"
  arch="$(detect_arch)"
  url="https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_linux_${arch}.tar.gz"
  tmp="$(mktemp -d)"

  info "Скачиваю GOST v${version} для linux_${arch}..."
  curl -fL "$url" -o "$tmp/gost.tar.gz"
  tar -xzf "$tmp/gost.tar.gz" -C "$tmp"
  find "$tmp" -type f -name gost -exec install -m 0755 {} "$BIN_PATH" \;
  rm -rf "$tmp"

  if [[ ! -x "$BIN_PATH" ]]; then
    err "Не удалось установить бинарник GOST."
    exit 1
  fi

  "$BIN_PATH" -V || true
}

write_config() {
  make_config_dir
  cat > "$CONFIG_FILE" <<EOF_CFG
MODE="$1"
LISTEN="$2"
FORWARD="$3"
COMMENT="$4"
EOF_CFG
  chmod 600 "$CONFIG_FILE"
}

write_service() {
  local listen_arg="$1"
  local forward_arg="${2:-}"

  if [[ -n "$forward_arg" ]]; then
    cat > "$SERVICE_FILE" <<EOF_SERVICE
[Unit]
Description=GOST Cascade Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN_PATH -L "$listen_arg" -F "$forward_arg"
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF_SERVICE
  else
    cat > "$SERVICE_FILE" <<EOF_SERVICE
[Unit]
Description=GOST Cascade Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN_PATH -L "$listen_arg"
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF_SERVICE
  fi

  systemctl daemon-reload
  systemctl enable --now "$SERVICE_NAME"
}

install_foreign_tls() {
  install_gost_binary
  make_config_dir

  local user pass port listen url
  user="$(ask 'Логин для FOREIGN' 'gost')"
  pass="$(ask 'Пароль для FOREIGN' "$(random_string)")"
  port="$(ask 'Порт FOREIGN' '443')"

  listen="relay+tls://${user}:${pass}@:${port}"
  url="relay+tls://${user}:${pass}@FOREIGN_IP:${port}"

  write_service "$listen"
  write_config "foreign-relay-tls" "$listen" "" "FOREIGN выходной узел relay+tls"

  ok "FOREIGN VPS установлен в режиме relay+tls."
  echo
  warn "На RU VPS в пункте установки надо будет указать такой URL:"
  echo "$url"
}

install_foreign_wss() {
  install_gost_binary
  make_config_dir

  local user pass port path domain cert key listen url
  user="$(ask 'Логин для FOREIGN' 'gost')"
  pass="$(ask 'Пароль для FOREIGN' "$(random_string)")"
  port="$(ask 'Порт FOREIGN' '443')"
  path="$(ask 'WSS путь' '/api/socket')"
  domain="$(ask 'Домен для self-signed сертификата CN' 'example.com')"

  cert="$CONFIG_DIR/cert.pem"
  key="$CONFIG_DIR/key.pem"

  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$key" \
    -out "$cert" \
    -days 3650 \
    -subj "/CN=$domain" >/dev/null 2>&1

  chmod 600 "$cert" "$key"

  listen="relay+wss://${user}:${pass}@:${port}?path=${path}&certFile=${cert}&keyFile=${key}"
  url="relay+wss://${user}:${pass}@FOREIGN_IP:${port}?path=${path}&secure=true"

  write_service "$listen"
  write_config "foreign-relay-wss-selfsigned" "$listen" "" "FOREIGN выходной узел relay+wss self-signed"

  ok "FOREIGN VPS установлен в режиме relay+wss self-signed."
  echo
  warn "На RU VPS в пункте установки надо будет указать такой URL:"
  echo "$url"
}

install_ru_node() {
  install_gost_binary
  make_config_dir

  local port foreign_url socks_user socks_pass listen
  port="$(ask 'Локальный SOCKS5 порт на RU VPS' '1080')"
  foreign_url="$(ask 'URL FOREIGN узла, например relay+tls://user:pass@1.2.3.4:443')"
  socks_user="$(ask 'Логин SOCKS5 на RU VPS, пусто = без авторизации' '')"

  if [[ -n "$socks_user" ]]; then
    socks_pass="$(ask 'Пароль SOCKS5 на RU VPS' "$(random_string)")"
    listen="socks5://${socks_user}:${socks_pass}@:${port}"
  else
    socks_pass=""
    listen="socks5://:${port}"
  fi

  write_service "$listen" "$foreign_url"
  write_config "ru-socks-to-foreign" "$listen" "$foreign_url" "RU промежуточный узел: SOCKS5 -> FOREIGN"

  ok "RU VPS установлен."
  echo
  warn "В клиенте подключайся к RU VPS:"
  echo "SOCKS5: RU_IP:${port}"
}

show_status() {
  info "Бинарник GOST:"
  if [[ -x "$BIN_PATH" ]]; then
    "$BIN_PATH" -V || true
  else
    echo "Не установлен"
  fi

  echo
  info "Конфигурация:"
  if [[ -f "$CONFIG_FILE" ]]; then
    cat "$CONFIG_FILE"
  else
    echo "Конфигурация не найдена"
  fi

  echo
  info "Служба systemd:"
  systemctl --no-pager status "$SERVICE_NAME" || true
}

show_logs() {
  journalctl -u "$SERVICE_NAME" -n 120 --no-pager || true
}

restart_service() {
  systemctl restart "$SERVICE_NAME"
  systemctl --no-pager status "$SERVICE_NAME" || true
}

stop_service() {
  systemctl stop "$SERVICE_NAME" || true
  ok "Служба остановлена."
}

install_menu_command() {
  install -m 0755 "$0" "$MENU_PATH"
  ok "Команда установлена: gost-menu"
}

self_update() {
  local url
  url="$(ask 'Raw-ссылка на gost-menu.sh' "$RAW_URL")"
  curl -fL "$url" -o /tmp/gost-menu.new
  bash -n /tmp/gost-menu.new
  install -m 0755 /tmp/gost-menu.new "$MENU_PATH"
  ok "Меню обновлено. Запуск: gost-menu"
}

uninstall_all() {
  warn "Будет удалён только GOST Cascade Manager."
  warn "Xray, sing-box, 3x-ui, nginx и другие конфиги НЕ трогаются."
  echo
  read -rp "Для удаления введи DELETE: " confirm
  if [[ "$confirm" != "DELETE" ]]; then
    warn "$(tr cancel)"
    return
  fi

  systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  rm -rf "$CONFIG_DIR"
  rm -f "$BIN_PATH"
  rm -f "$MENU_PATH"
  ok "GOST Cascade Manager полностью удалён."
}

language_menu() {
  make_config_dir
  echo
  info "Выбор языка / Language"
  echo "1) Русский"
  echo "2) English"
  read -rp "> " lang_choice
  case "$lang_choice" in
    1) LANGUAGE="ru" ;;
    2) LANGUAGE="en" ;;
    *) LANGUAGE="ru" ;;
  esac
  save_language
}

print_menu_ru() {
  echo -e "${BLUE}=== GOST Cascade Manager ===${NC}"
  echo
  echo "1) Установить FOREIGN выходной узел: relay+tls"
  echo "2) Установить FOREIGN выходной узел: relay+wss self-signed"
  echo "3) Установить RU промежуточный узел: локальный SOCKS5 -> FOREIGN"
  echo "4) Статус / конфигурация"
  echo "5) Логи"
  echo "6) Перезапустить службу"
  echo "7) Остановить службу"
  echo "8) Установить команду gost-menu"
  echo "9) Обновить меню с GitHub"
  echo "10) Полностью удалить GOST cascade"
  echo "11) Сменить язык"
  echo "0) Выход"
}

print_menu_en() {
  echo -e "${BLUE}=== GOST Cascade Manager ===${NC}"
  echo
  echo "1) Install FOREIGN exit node: relay+tls"
  echo "2) Install FOREIGN exit node: relay+wss self-signed"
  echo "3) Install RU middle node: local SOCKS5 -> FOREIGN"
  echo "4) Status / config"
  echo "5) Logs"
  echo "6) Restart service"
  echo "7) Stop service"
  echo "8) Install menu command: gost-menu"
  echo "9) Update menu from GitHub"
  echo "10) Remove GOST cascade completely"
  echo "11) Change language"
  echo "0) Exit"
}

main_menu() {
  while true; do
    clear || true
    if [[ "$LANGUAGE" == "en" ]]; then
      print_menu_en
    else
      print_menu_ru
    fi
    echo
    read -rp "> " choice
    case "$choice" in
      1) install_foreign_tls; pause ;;
      2) install_foreign_wss; pause ;;
      3) install_ru_node; pause ;;
      4) show_status; pause ;;
      5) show_logs; pause ;;
      6) restart_service; pause ;;
      7) stop_service; pause ;;
      8) install_menu_command; pause ;;
      9) self_update; pause ;;
      10) uninstall_all; pause ;;
      11) language_menu; pause ;;
      0) exit 0 ;;
      *) warn "$(tr wrong)"; sleep 1 ;;
    esac
  done
}

need_root
load_language

if [[ ! -f "$LANG_FILE" ]]; then
  language_menu
fi

main_menu
