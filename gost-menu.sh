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
SERVICE_BACKUP_FILE="/etc/systemd/system/${SERVICE_NAME}.service.backup"
RAW_URL="https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
LANGUAGE="ru"

ok(){ echo -e "${GREEN}$*${NC}"; }
warn(){ echo -e "${YELLOW}$*${NC}"; }
err(){ echo -e "${RED}$*${NC}"; }
info(){ echo -e "${BLUE}$*${NC}"; }

need_root(){
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "Запусти от root: sudo bash gost-menu.sh"
    exit 1
  fi
}

make_config_dir(){ mkdir -p "$CONFIG_DIR"; chmod 700 "$CONFIG_DIR"; }
load_language(){
  if [[ -f "$LANG_FILE" ]]; then LANGUAGE="$(cat "$LANG_FILE" 2>/dev/null || echo ru)"; else LANGUAGE="ru"; fi
  [[ "$LANGUAGE" == "en" || "$LANGUAGE" == "ru" ]] || LANGUAGE="ru"
}
save_language(){ make_config_dir; echo "$LANGUAGE" > "$LANG_FILE"; }

msg(){
  local key="$1"
  case "$LANGUAGE:$key" in
    ru:pause) echo "Нажми Enter, чтобы продолжить..." ;;
    en:pause) echo "Press Enter to continue..." ;;
    ru:cancel) echo "Отменено." ;;
    en:cancel) echo "Cancelled." ;;
    ru:wrong) echo "Неверный пункт меню." ;;
    en:wrong) echo "Wrong menu item." ;;
    *) echo "$key" ;;
  esac
}
pause(){ local p; p="$(msg pause)"; read -rp "$p" _ || true; }
ask(){
  local prompt="$1" default="${2:-}" value
  if [[ -n "$default" ]]; then read -rp "$prompt [$default]: " value; echo "${value:-$default}"; else read -rp "$prompt: " value; echo "$value"; fi
}
random_string(){ openssl rand -hex 12; }

install_deps(){
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl wget tar gzip ca-certificates jq openssl qrencode netcat-openbsd dnsutils
}

detect_arch(){
  local arch; arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv7*) echo "armv7" ;;
    *) err "Неподдерживаемая архитектура: $arch"; exit 1 ;;
  esac
}

latest_gost_version(){
  local version
  version="$(curl -fsSL https://api.github.com/repos/go-gost/gost/releases/latest | jq -r '.tag_name' | sed 's/^v//' || true)"
  if [[ -z "$version" || "$version" == "null" ]]; then version="3.2.6"; fi
  echo "$version"
}

install_gost_binary(){
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
  [[ -x "$BIN_PATH" ]] || { err "Не удалось установить бинарник GOST."; exit 1; }
  "$BIN_PATH" -V || true
}


backup_service(){
  if [[ -f "$SERVICE_FILE" ]]; then
    cp -a "$SERVICE_FILE" "$SERVICE_BACKUP_FILE"
    ok "Создан backup: $SERVICE_BACKUP_FILE"
  fi
}

restore_backup(){
  if [[ ! -f "$SERVICE_BACKUP_FILE" ]]; then
    err "Backup не найден: $SERVICE_BACKUP_FILE"
    return 1
  fi
  cp -a "$SERVICE_BACKUP_FILE" "$SERVICE_FILE"
  systemctl daemon-reload
  systemctl restart "$SERVICE_NAME" || true
  ok "Backup восстановлен."
  systemctl --no-pager status "$SERVICE_NAME" || true
}

extract_url_param(){
  local url="$1" key="$2"
  echo "$url" | tr '&' '
' | sed -n "s/^.*[?&]${key}=//p" | head -n1 | cut -d'&' -f1
}

extract_port(){
  local url="$1" default_port="${2:-443}"
  local no_query hostport port
  no_query="${url%%\?*}"
  hostport="${no_query##*@}"
  port="${hostport##*:}"
  if [[ "$port" =~ ^[0-9]+$ ]]; then echo "$port"; else echo "$default_port"; fi
}

write_config(){
  make_config_dir
  cat > "$CONFIG_FILE" <<EOF_CFG
MODE="$1"
LISTEN="$2"
FORWARD="$3"
SOCKS_USER="${4:-}"
SOCKS_PASS="${5:-}"
SOCKS_PORT="${6:-}"
FOREIGN_IP="${7:-}"
COMMENT="$8"
EOF_CFG
  chmod 600 "$CONFIG_FILE"
}

write_service(){
  local listen_arg="$1" forward_arg="${2:-}"
  backup_service
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
  systemctl restart "$SERVICE_NAME"
}

install_foreign_tls(){
  install_gost_binary; make_config_dir
  local user pass port listen url
  user="$(ask 'Логин для FOREIGN' 'prado')"
  pass="$(ask 'Пароль для FOREIGN' "$(random_string)")"
  port="$(ask 'Порт FOREIGN' '443')"
  listen="socks5+tls://${user}:${pass}@:${port}"
  url="socks5+tls://${user}:${pass}@FOREIGN_IP:${port}"
  write_service "$listen"
  write_config "foreign-socks5-tls" "$listen" "" "" "" "" "" "FOREIGN выходной узел socks5+tls"
  ok "FOREIGN VPS установлен в режиме socks5+tls."
  echo; warn "На RU VPS в пункте установки укажи такой URL, заменив FOREIGN_IP на IP иностранного VPS:"; echo "$url"
}

install_foreign_wss(){
  install_gost_binary; make_config_dir
  local user pass port path domain cert key listen url
  user="$(ask 'Логин для FOREIGN' 'prado')"
  pass="$(ask 'Пароль для FOREIGN' "$(random_string)")"
  port="$(ask 'Порт FOREIGN' '443')"
  path="$(ask 'WSS путь' '/api/socket')"
  domain="$(ask 'Домен для self-signed сертификата CN' 'example.com')"
  cert="$CONFIG_DIR/cert.pem"; key="$CONFIG_DIR/key.pem"
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$key" -out "$cert" -days 3650 -subj "/CN=$domain" >/dev/null 2>&1
  chmod 600 "$cert" "$key"
  listen="socks5+wss://${user}:${pass}@:${port}?path=${path}&certFile=${cert}&keyFile=${key}"
  url="socks5+wss://${user}:${pass}@FOREIGN_IP:${port}?path=${path}&secure=true"
  write_service "$listen"
  write_config "foreign-socks5-wss-selfsigned" "$listen" "" "" "" "" "" "FOREIGN выходной узел socks5+wss self-signed"
  ok "FOREIGN VPS установлен в режиме socks5+wss self-signed."
  echo; warn "На RU VPS в пункте установки укажи такой URL, заменив FOREIGN_IP на IP иностранного VPS:"; echo "$url"
}


install_foreign_relay_wss(){
  install_gost_binary; make_config_dir
  local port path domain cert key listen url
  port="$(ask 'Порт FOREIGN relay+wss' '443')"
  path="$(ask 'WSS путь' '/api/socket')"
  domain="$(ask 'Домен для self-signed сертификата CN' 'gost.local')"
  cert="$CONFIG_DIR/relay-wss-cert.pem"; key="$CONFIG_DIR/relay-wss-key.pem"
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$key" -out "$cert" -days 3650 -subj "/CN=$domain" >/dev/null 2>&1
  chmod 600 "$cert" "$key"

  # ВАЖНО: для relay+wss в GOST v3 не используем ?auth=user:pass.
  # На практике это приводило к ошибке: illegal base64 data at input byte 5.
  # Авторизация остаётся на входе RU SOCKS5, а канал RU -> FOREIGN закрыт WSS/TLS.
  listen="relay+wss://:${port}?path=${path}&certFile=${cert}&keyFile=${key}"
  url="relay+wss://FOREIGN_IP:${port}?path=${path}&secure=false"

  write_service "$listen"
  write_config "foreign-relay-wss-selfsigned" "$listen" "" "" "" "" "" "FOREIGN выходной узел relay+wss self-signed без auth"
  ok "FOREIGN VPS установлен в режиме relay+wss self-signed."
  echo
  warn "На RU VPS в пункте 3 укажи такой URL, заменив FOREIGN_IP на IP иностранного VPS:"
  echo "$url"
  echo
  warn "Важно: логин/пароль для relay+wss не указываем. Авторизация остаётся на RU SOCKS5."
}

install_ru_node(){
  install_gost_binary; make_config_dir
  local port foreign_url socks_user socks_pass listen foreign_ip
  port="$(ask 'Локальный SOCKS5 порт на RU VPS' '1080')"
  foreign_url="$(ask 'URL FOREIGN узла, например socks5+tls://user:pass@194.116.172.222:443')"
  socks_user="$(ask 'Логин SOCKS5 на RU VPS, пусто = без авторизации' 'prado')"
  if [[ -n "$socks_user" ]]; then
    socks_pass="$(ask 'Пароль SOCKS5 на RU VPS' "$(random_string)")"
    listen="socks5://${socks_user}:${socks_pass}@:${port}"
  else
    socks_pass=""
    listen="socks5://:${port}"
  fi
  foreign_ip="$(echo "$foreign_url" | sed -E 's#^[^@]+@([^:/?]+).*#\1#')"
  write_service "$listen" "$foreign_url"
  write_config "ru-socks-to-foreign" "$listen" "$foreign_url" "$socks_user" "$socks_pass" "$port" "$foreign_ip" "RU промежуточный узел: SOCKS5 -> FOREIGN"
  ok "RU VPS установлен."
  echo; warn "В клиенте подключайся к RU VPS:"; echo "SOCKS5: RU_IP:${port}"
  show_client_link
}

get_public_ip(){
  curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

load_config_env(){
  if [[ ! -f "$CONFIG_FILE" ]]; then err "Конфиг не найден: $CONFIG_FILE"; return 1; fi
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
}

show_client_link(){
  load_config_env || return 0
  if [[ "${MODE:-}" != "ru-socks-to-foreign" ]]; then
    warn "QR/ссылка нужны на RU узле. Сейчас режим: ${MODE:-unknown}"
    return 0
  fi
  local ip link
  ip="$(ask 'IP или домен RU VPS для ссылки' "$(get_public_ip)")"
  if [[ -n "${SOCKS_USER:-}" ]]; then
    link="socks://${SOCKS_USER}:${SOCKS_PASS}@${ip}:${SOCKS_PORT}"
  else
    link="socks://${ip}:${SOCKS_PORT}"
  fi
  echo
  info "Ссылка подключения SOCKS5:"
  echo "$link"
  echo
  info "Данные для v2rayN:"
  echo "Тип: SOCKS"
  echo "Адрес: $ip"
  echo "Порт: ${SOCKS_PORT}"
  echo "Логин: ${SOCKS_USER:-без логина}"
  echo "Пароль: ${SOCKS_PASS:-без пароля}"
  echo
  if command -v qrencode >/dev/null 2>&1; then
    info "QR-code:"
    qrencode -t ANSIUTF8 "$link" || true
  else
    warn "qrencode не установлен. Установи: apt install -y qrencode"
  fi
}

test_cascade(){
  load_config_env || return 0
  if [[ "${MODE:-}" != "ru-socks-to-foreign" ]]; then warn "Тест запускается на RU узле."; return 0; fi
  local proxy
  if [[ -n "${SOCKS_USER:-}" ]]; then proxy="socks5h://${SOCKS_USER}:${SOCKS_PASS}@127.0.0.1:${SOCKS_PORT}"; else proxy="socks5h://127.0.0.1:${SOCKS_PORT}"; fi
  info "Проверяю внешний IP через локальный SOCKS5..."
  curl -x "$proxy" --max-time 15 https://api.ipify.org ; echo
}


setup_domain_letsencrypt(){
  load_config_env || return 0
  if [[ "${MODE:-}" != foreign-relay-wss* ]]; then
    warn "Этот пункт запускается на FOREIGN relay+wss узле. Сейчас режим: ${MODE:-unknown}"
    warn "Сначала установи FOREIGN relay+wss через пункт 14."
    return 0
  fi

  local domain server_ip dns_ip port path cert key listen
  domain="$(ask 'Введите ваш домен (example.com)')"
  if [[ -z "$domain" ]]; then warn "Домен не указан."; return 0; fi

  server_ip="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"
  dns_ip="$(dig +short A "$domain" | tail -n1 || true)"

  echo
  info "Проверка DNS:"
  echo "Домен: $domain"
  echo "A-запись домена: ${dns_ip:-не найдена}"
  echo "IP этого сервера: $server_ip"

  if [[ -z "$dns_ip" || "$dns_ip" != "$server_ip" ]]; then
    err "DNS пока не указывает на этот FOREIGN VPS."
    warn "Создай или проверь A-запись:"
    echo "$domain -> $server_ip"
    warn "После обновления DNS запусти этот пункт снова."
    return 1
  fi

  port="$(extract_port "${LISTEN:-}" 443)"
  path="$(extract_url_param "${LISTEN:-}" path)"
  [[ -n "$path" ]] || path="/api/socket"

  install_deps
  apt-get install -y certbot

  backup_service
  systemctl stop "$SERVICE_NAME" || true

  certbot certonly --standalone -d "$domain"

  cert="/etc/letsencrypt/live/${domain}/fullchain.pem"
  key="/etc/letsencrypt/live/${domain}/privkey.pem"
  if [[ ! -f "$cert" || ! -f "$key" ]]; then
    err "Сертификат не найден после certbot. Возвращаю службу как была."
    systemctl restart "$SERVICE_NAME" || true
    return 1
  fi

  listen="relay+wss://:${port}?path=${path}&certFile=${cert}&keyFile=${key}"
  write_service "$listen"
  write_config "foreign-relay-wss-letsencrypt" "$listen" "" "" "" "" "$domain" "FOREIGN relay+wss с Let's Encrypt"
  ok "Домен и Let's Encrypt настроены."
  warn "На RU VPS теперь можно переключить FOREIGN адрес на домен через пункт 16."
  echo "relay+wss://${domain}:${port}?path=${path}"
}

switch_foreign_to_domain(){
  load_config_env || return 0
  if [[ "${MODE:-}" != "ru-socks-to-foreign" ]]; then
    warn "Этот пункт запускается на RU узле. Сейчас режим: ${MODE:-unknown}"
    return 0
  fi

  local domain port path new_forward listen
  domain="$(ask 'Введите домен вашего FOREIGN VPS (example.com)')"
  if [[ -z "$domain" ]]; then warn "Домен не указан."; return 0; fi

  port="$(extract_port "${FORWARD:-}" 443)"
  path="$(extract_url_param "${FORWARD:-}" path)"
  [[ -n "$path" ]] || path="/api/socket"

  if [[ "${FORWARD:-}" == relay+wss://* ]]; then
    new_forward="relay+wss://${domain}:${port}?path=${path}"
  elif [[ "${FORWARD:-}" == socks5+wss://* ]]; then
    warn "Обнаружен socks5+wss. Для self-signed сертификата может быть нужен secure=false."
    new_forward="socks5+wss://${domain}:${port}?path=${path}"
  elif [[ "${FORWARD:-}" == socks5+tls://* ]]; then
    warn "Обнаружен socks5+tls. Переключаю только адрес на домен, логин/пароль сохранить автоматически сложно."
    warn "Для socks5+tls лучше переустановить RU пунктом 3 и указать полный FOREIGN URL с доменом."
    return 1
  else
    err "Неизвестный FOREIGN URL: ${FORWARD:-empty}"
    return 1
  fi

  listen="${LISTEN}"
  write_service "$listen" "$new_forward"
  write_config "ru-socks-to-foreign" "$listen" "$new_forward" "${SOCKS_USER:-}" "${SOCKS_PASS:-}" "${SOCKS_PORT:-}" "$domain" "RU промежуточный узел: SOCKS5 -> FOREIGN domain"
  ok "RU переключён на домен FOREIGN."
  echo "Новый FORWARD: $new_forward"
}

show_status(){
  info "Бинарник GOST:"
  if [[ -x "$BIN_PATH" ]]; then "$BIN_PATH" -V || true; else echo "Не установлен"; fi
  echo; info "Конфигурация:"
  if [[ -f "$CONFIG_FILE" ]]; then cat "$CONFIG_FILE"; else echo "Конфигурация не найдена"; fi
  echo; info "Слушающие порты:"
  ss -lntp | grep gost || true
  echo; info "Служба systemd:"
  systemctl --no-pager status "$SERVICE_NAME" || true
}
show_logs(){ journalctl -u "$SERVICE_NAME" -n 120 --no-pager || true; }
restart_service(){ systemctl restart "$SERVICE_NAME"; systemctl --no-pager status "$SERVICE_NAME" || true; }
stop_service(){ systemctl stop "$SERVICE_NAME" || true; ok "Служба остановлена."; }
install_menu_command(){
  make_config_dir
  local tmp source_file
  tmp="$(mktemp)"
  source_file="${BASH_SOURCE[0]:-$0}"

  # При запуске через bash <(curl ...) скрипт живёт как /dev/fd/XX.
  # Старый вариант install "$0" часто копировал не тот файл или пустышку.
  if [[ -r "$source_file" ]]; then
    cat "$source_file" > "$tmp" || true
  fi

  # Если самокопирование не удалось, берём актуальный скрипт с GitHub RAW.
  if [[ ! -s "$tmp" ]] || ! bash -n "$tmp" >/dev/null 2>&1; then
    warn "Не удалось корректно скопировать текущий скрипт, скачиваю с GitHub..."
    curl -fsSL "$RAW_URL" -o "$tmp"
  fi

  bash -n "$tmp"
  install -m 0755 "$tmp" "$MENU_PATH"
  ln -sf "$MENU_PATH" /usr/bin/gost-menu 2>/dev/null || true
  rm -f "$tmp"
  hash -r 2>/dev/null || true

  ok "Команда установлена: gost-menu"
  info "Путь: $(command -v gost-menu || echo "$MENU_PATH")"
  warn "Если команда не запускается в текущей SSH-сессии, выйди из неё и зайди заново, либо выполни: hash -r"
}

self_update(){
  local url
  echo; info "Обновление меню с GitHub"; echo "Текущая ссылка: $RAW_URL"
  url="$(ask 'Raw-ссылка на gost-menu.sh' "$RAW_URL")"
  curl -fL "$url" -o /tmp/gost-menu.new
  bash -n /tmp/gost-menu.new
  install -m 0755 /tmp/gost-menu.new "$MENU_PATH"
  ok "Меню обновлено. Запуск: gost-menu"
  warn "Если ты запускал старый файл вручную, закрой его и запусти команду: gost-menu"
}

uninstall_all(){
  warn "Будет удалён только GOST Cascade Manager."
  warn "Xray, sing-box, 3x-ui, nginx и другие конфиги НЕ трогаются."
  echo; read -rp "Для удаления введи DELETE: " confirm
  if [[ "$confirm" != "DELETE" ]]; then warn "$(msg cancel)"; return; fi
  systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
  pkill -9 gost 2>/dev/null || true
  rm -f "$SERVICE_FILE"; systemctl daemon-reload
  rm -rf "$CONFIG_DIR"; rm -f "$BIN_PATH" "$MENU_PATH"
  ok "GOST Cascade Manager полностью удалён."
}

language_menu(){
  make_config_dir
  echo; info "Выбор языка / Language"
  echo "1) Русский"; echo "2) English"
  read -rp "> " lang_choice
  case "$lang_choice" in 2) LANGUAGE="en" ;; *) LANGUAGE="ru" ;; esac
  save_language
}

print_menu_ru(){
  echo -e "${BLUE}=== GOST Cascade Manager ===${NC}"
  echo
  echo "1) Установить FOREIGN выходной узел: socks5+tls  РЕКОМЕНДУЕТСЯ"
  echo "2) Установить FOREIGN выходной узел: socks5+wss self-signed"
  echo "3) Установить RU промежуточный узел: локальный SOCKS5 -> FOREIGN"
  echo "4) Статус / конфигурация"
  echo "5) Логи"
  echo "6) Перезапустить службу"
  echo "7) Остановить службу"
  echo "8) Установить команду gost-menu"
  echo "9) Обновить меню с GitHub"
  echo "10) Полностью удалить GOST cascade"
  echo "11) Сменить язык"
  echo "12) Показать ссылку подключения и QR-code"
  echo "13) Проверить каскад через api.ipify.org"
  echo "14) Установить FOREIGN выходной узел: relay+wss  WSS/TLS ТУННЕЛЬ"
  echo "15) Настроить домен и Let's Encrypt для FOREIGN relay+wss"
  echo "16) Переключить FOREIGN адрес на домен на RU"
  echo "17) Восстановить backup gost.service"
  echo "0) Выход"
}
print_menu_en(){
  echo -e "${BLUE}=== GOST Cascade Manager ===${NC}"
  echo
  echo "1) Install FOREIGN exit node: socks5+tls RECOMMENDED"
  echo "2) Install FOREIGN exit node: socks5+wss self-signed"
  echo "3) Install RU middle node: local SOCKS5 -> FOREIGN"
  echo "4) Status / config"
  echo "5) Logs"
  echo "6) Restart service"
  echo "7) Stop service"
  echo "8) Install menu command: gost-menu"
  echo "9) Update menu from GitHub"
  echo "10) Remove GOST cascade completely"
  echo "11) Change language"
  echo "12) Show connection link and QR-code"
  echo "13) Test cascade through api.ipify.org"
  echo "14) Install FOREIGN exit node: relay+wss WSS/TLS tunnel"
  echo "15) Configure domain and Let's Encrypt for FOREIGN relay+wss"
  echo "16) Switch FOREIGN address to domain on RU"
  echo "17) Restore gost.service backup"
  echo "0) Exit"
}

main_menu(){
  while true; do
    load_language
    clear || true
    if [[ "$LANGUAGE" == "en" ]]; then print_menu_en; else print_menu_ru; fi
    echo; read -rp "> " choice
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
      12) show_client_link; pause ;;
      13) test_cascade; pause ;;
      14) install_foreign_relay_wss; pause ;;
      15) setup_domain_letsencrypt; pause ;;
      16) switch_foreign_to_domain; pause ;;
      17) restore_backup; pause ;;
      0) exit 0 ;;
      *) warn "$(msg wrong)"; sleep 1 ;;
    esac
  done
}

need_root
make_config_dir
load_language
if [[ ! -f "$LANG_FILE" ]]; then language_menu; fi
main_menu
