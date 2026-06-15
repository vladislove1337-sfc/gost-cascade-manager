# GOST Cascade Manager

<p align="center">
  <img src="assets/banner(3).png" width="800">
</p>

<h1 align="center">
SingBox Node Cascade Manager
</h1>

Меню-скрипт для настройки аварийного каскада на GOST v3.

Схема работы:

```text
Клиент / v2rayN / браузер
        ↓
RU VPS — локальный SOCKS5 вход
        ↓
FOREIGN VPS — выходной узел
        ↓
Internet
```

Скрипт не трогает Xray, sing-box, 3x-ui, nginx и другие ваши сервисы. Он управляет только службой `gost.service`, бинарником `/usr/local/bin/gost` и каталогом `/etc/gost-cascade`.

---

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

После первой установки можно установить короткую команду через пункт меню:

```text
8) Установить команду gost-menu
```

После этого меню запускается так:

```bash
gost-menu
```

---

## Основные режимы

### 1. Стабильный режим: SOCKS5 + TLS

```text
Клиент
 ↓
RU VPS: SOCKS5
 ↓
socks5+tls
 ↓
FOREIGN VPS
 ↓
Internet
```

Это самый простой и стабильный режим, который рекомендуется использовать первым.

---

### 2. WSS/TLS режим: relay+wss

```text
Клиент
 ↓
RU VPS: SOCKS5
 ↓
relay+wss / HTTPS WebSocket / 443
 ↓
FOREIGN VPS
 ↓
Internet
```

В этом режиме участок `RU VPS -> FOREIGN VPS` идёт через WSS на 443 порту.

Важно: в режиме `relay+wss` авторизация `auth=user:password` между RU и FOREIGN не используется. Авторизация остаётся на входе RU SOCKS5.

Рабочая схема:

FOREIGN:

```text
relay+wss://:443?path=/api/socket&certFile=...&keyFile=...
```

RU:

```text
relay+wss://FOREIGN_IP:443?path=/api/socket&secure=false
```

При использовании настоящего сертификата Let's Encrypt `secure=false` больше не нужен.

---

## Настройка домена и Let's Encrypt

Если у вас есть домен, можно сделать A-запись на FOREIGN VPS:

```text
ваш домен (example.com) -> IP вашего FOREIGN VPS
```

После обновления DNS на FOREIGN VPS откройте меню и выберите:

```text
15) Настроить домен и Let's Encrypt для FOREIGN relay+wss
```

Скрипт:

- проверит, что домен указывает на IP текущего FOREIGN VPS;
- остановит `gost.service`;
- установит `certbot`;
- получит сертификат Let's Encrypt;
- перепишет `gost.service` на сертификаты из `/etc/letsencrypt/live/...`;
- запустит GOST обратно.

Если DNS ещё не обновился, скрипт покажет, какую A-запись нужно создать.

Для выпуска Let's Encrypt сертификата сервер должен быть доступен по домену извне. Обычно также нужно, чтобы порт `80/tcp` не был заблокирован firewall-ом или панелью хостера.

---

## Переключение RU на домен FOREIGN

После получения сертификата на FOREIGN VPS на RU VPS выберите:

```text
16) Переключить FOREIGN адрес на домен на RU
```

Скрипт заменит FOREIGN IP на домен в строке `-F`.

Было:

```text
relay+wss://123.123.123.123:443?path=/api/socket&secure=false
```

Станет:

```text
relay+wss://example.com:443?path=/api/socket
```

---

## QR-code и ссылка подключения

На RU VPS выберите:

```text
12) Показать ссылку подключения и QR-code
```

Скрипт покажет SOCKS5-ссылку вида:

```text
socks://user:password@RU_IP:1080
```

И QR-code для быстрого добавления в клиент, если установлен `qrencode`.

---

## Проверка каскада

На RU VPS выберите:

```text
13) Проверить каскад через api.ipify.org
```

Или вручную:

```bash
curl -x socks5h://user:password@127.0.0.1:1080 https://api.ipify.org ; echo
```

Если всё работает, команда покажет IP FOREIGN VPS.

---

## Backup и откат

Перед изменением `gost.service` скрипт создаёт backup:

```text
/etc/systemd/system/gost.service.backup
```

Для отката выберите:

```text
17) Восстановить backup gost.service
```

---

## Обновление

Через меню:

```text
9) Обновить меню с GitHub
```

Или вручную:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

---

## Удаление

```text
10) Полностью удалить GOST cascade
```

Удаляется только GOST Cascade Manager:

- `gost.service`;
- `/usr/local/bin/gost`;
- `/usr/local/bin/gost-menu`;
- `/etc/gost-cascade`.

Xray, sing-box, 3x-ui и другие сервисы не трогаются.
