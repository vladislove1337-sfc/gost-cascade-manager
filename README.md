# GOST Cascade Manager

Готовое меню для аварийного независимого каскада на **GOST v3**.

Схема:

```text
Клиент → RU VPS SOCKS5 → FOREIGN VPS → Интернет
```

Проект **не трогает** Xray, sing-box, 3x-ui, nginx и существующие рабочие конфиги.

Создаёт только:

```text
/usr/local/bin/gost
/usr/local/bin/gost-menu
/etc/gost-cascade/
/etc/systemd/system/gost.service
```

---

## Быстрая установка с GitHub

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

После установки команды меню:

```bash
gost-menu
```

---

## Как ставить каскад

### 1. Сначала FOREIGN VPS

На иностранном сервере запускаешь меню:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

Выбираешь один из пунктов:

```text
1) Установить FOREIGN выходной узел: relay+tls
```

или:

```text
2) Установить FOREIGN выходной узел: relay+wss self-signed
```

После установки скрипт покажет готовый URL вида:

```text
relay+tls://user:password@FOREIGN_IP:443
```

или:

```text
relay+wss://user:password@FOREIGN_IP:443?path=/api/socket&secure=true
```

`FOREIGN_IP` нужно заменить на реальный IP иностранного VPS.

---

### 2. Потом RU VPS

На российском сервере запускаешь меню:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

Выбираешь:

```text
3) Установить RU промежуточный узел: локальный SOCKS5 -> FOREIGN
```

Вставляешь URL иностранного узла.

После этого клиент подключается к RU VPS по SOCKS5:

```text
RU_IP:1080
```

А наружу трафик выходит через FOREIGN VPS.

---

## Управление

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

Остановка:

```bash
systemctl stop gost
```

---

## Обновление

В меню выбери:

```text
9) Обновить меню с GitHub
```

Ссылка уже прописана:

```text
https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh
```

---

## Полное удаление

В меню выбери:

```text
10) Полностью удалить GOST cascade
```

Удаляется только GOST Cascade Manager. Xray, sing-box, 3x-ui и остальные сервисы не затрагиваются.
