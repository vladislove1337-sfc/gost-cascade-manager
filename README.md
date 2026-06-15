# GOST Cascade Manager

<p align="center">
  <img src="banner (3).png" width="800">
</p>

<h1 align="center">
SingBox Node Cascade Manager
</h1>

Меню для аварийного каскада на GOST v3.

Базовая рабочая схема:

```text
Клиент -> RU VPS SOCKS5 -> FOREIGN VPS socks5+tls -> Интернет
```

Дополнительная WSS-схема:

```text
Клиент -> RU VPS SOCKS5 -> FOREIGN VPS relay+wss -> Интернет
```

Это отдельная резервная схема. Она не трогает Xray, sing-box, 3x-ui, nginx и существующие конфиги.

## Установка одной командой

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

## Запуск меню после установки

После установки команды меню запускается так:

```bash
gost-menu
```

Если команда отсутствует, запусти меню через raw-ссылку и выбери:

```text
8) Установить команду gost-menu
```

## Что есть в этой версии

- Основной рабочий режим `socks5+tls`.
- QR-code для ссылки подключения через `qrencode`.
- Тест каскада через `api.ipify.org`.
- Меню по умолчанию на русском.
- Добавлен FOREIGN-режим `relay+wss` без auth между RU и FOREIGN. Это исправляет ошибку `illegal base64 data at input byte 5`.

## Рекомендуемая настройка SOCKS5 + TLS

### 1. На FOREIGN VPS

Запусти меню и выбери:

```text
1) Установить FOREIGN выходной узел: socks5+tls
```

Пример результата:

```text
socks5+tls://prado:1234567890@FOREIGN_IP:443
```

Скопируй эту ссылку и замени `FOREIGN_IP` на настоящий IP иностранного VPS.

### 2. На RU VPS

Запусти меню и выбери:

```text
3) Установить RU промежуточный узел: локальный SOCKS5 -> FOREIGN
```

В поле FOREIGN URL вставь ссылку вида:

```text
socks5+tls://prado:1234567890@222.222.222.222:443
```

После установки выбери:

```text
12) Показать ссылку подключения и QR-code
```

## Режим relay+wss

На FOREIGN VPS выбери:

```text
14) Установить FOREIGN выходной узел: relay+wss  WSS/TLS ТУННЕЛЬ
```

Меню выдаст ссылку вида:

```text
relay+wss://FOREIGN_IP:443?path=/api/socket&secure=false
```

На RU VPS выбери пункт 3 и вставь эту ссылку, заменив `FOREIGN_IP` на настоящий IP иностранного VPS.

Важно: в `relay+wss` логин/пароль между RU и FOREIGN не указываются. Авторизация остаётся на входе RU SOCKS5. Это сделано специально: параметр `auth=user:pass` в `relay+wss` на GOST v3 приводил к падению FOREIGN с ошибкой `illegal base64 data at input byte 5`. Основным стабильным вариантом всё равно остаётся `socks5+tls`, который уже проверен.

## Проверка

На RU VPS:

```bash
curl -x socks5h://USER:PASS@127.0.0.1:1080 https://api.ipify.org ; echo
```

Должен вернуться IP FOREIGN VPS.

## v2rayN

Добавь сервер типа SOCKS:

```text
Адрес: IP RU VPS
Порт: 1080
Логин: указанный логин
Пароль: указанный пароль
```

Сайты должны видеть IP иностранного VPS.

## Обновление

В меню выбери:

```text
9) Обновить меню с GitHub
```

Или вручную:

```bash
curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh -o /usr/local/bin/gost-menu
chmod +x /usr/local/bin/gost-menu
```

## Удаление

В меню выбери:

```text
10) Полностью удалить GOST cascade
```

Удаляются только:

```text
/usr/local/bin/gost
/usr/local/bin/gost-menu
/etc/gost-cascade/
/etc/systemd/system/gost.service
```
