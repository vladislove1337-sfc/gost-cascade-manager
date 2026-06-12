# GOST Cascade Manager 🇷🇺➡️🌍

Готовое меню для создания аварийного независимого каскада на базе **GOST v3**.

Схема работы:

```
Клиент → RU VPS (SOCKS5) → Foreign VPS → Интернет
```

Проект не использует и не изменяет:

- Xray-core
- sing-box
- 3x-ui
- nginx
- существующие VPN конфиги

Создаются только:

- `/usr/local/bin/gost`
- `/usr/local/bin/gost-menu`
- `/etc/gost-cascade/`
- `/etc/systemd/system/gost.service`

---

## 🚀 Быстрая установка

Одна команда:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

После установки меню вызывается командой:

```bash
gost-menu
```

---

# Возможности меню

- 🇷🇺 Русский язык
- 🇬🇧 Английский язык
- Установка Foreign VPS
- Установка RU Cascade VPS
- Проверка статуса
- Перезапуск службы
- Просмотр логов
- Полное удаление
- Обновление скрипта напрямую с GitHub

---

# Рекомендуемая установка

## 1. Foreign VPS

Сначала запускаем меню на иностранном сервере.

Выбираем:

```
Установить Foreign VPS
```

Он станет выходным сервером.

---

## 2. RU VPS

Потом запускаем меню на российском сервере.

Выбираем:

```
Установить RU Cascade VPS
```

Вводим IP Foreign VPS.

Готовая схема:

```
ПК
 ↓
RU VPS
 ↓
Foreign VPS
 ↓
Internet
```

---

# Управление

Статус:

```bash
systemctl status gost
```

Логи:

```bash
journalctl -u gost -f
```

Перезапуск:

```bash
systemctl restart gost
```

---

# Обновление

В меню выбрать:

```
9) Обновить с GitHub
```

Скрипт сам скачает свежую версию.

---

GOST Cascade Manager — резервный каскад, независимый от Xray и sing-box.
