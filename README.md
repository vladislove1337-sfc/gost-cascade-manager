# GOST Cascade Manager

Готовое меню для аварийного каскада на **GOST v3**.

Схема:

```text
Клиент -> RU VPS SOCKS5 -> FOREIGN VPS -> Интернет
```

Скрипт **не трогает** Xray, sing-box, 3x-ui, nginx и уже существующие конфиги. Он создаёт только:

- `/usr/local/bin/gost`
- `/usr/local/bin/gost-menu`
- `/etc/gost-cascade/`
- `/etc/systemd/system/gost.service`

## Быстрая установка с GitHub

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

## Локальный запуск после загрузки файлов на VPS

```bash
sudo bash gost-menu.sh
```

## Рекомендуемая установка

### 1. На FOREIGN VPS

Сначала запускаешь меню на иностранном VPS и выбираешь один из пунктов:

```text
1) Установить FOREIGN выходной узел: relay+tls
```

или:

```text
2) Установить FOREIGN выходной узел: relay+wss self-signed
```

После установки скрипт покажет URL вида:

```text
relay+tls://user:password@FOREIGN_IP:443
```

Вместо `FOREIGN_IP` подставь реальный IP иностранного VPS.

### 2. На RU VPS

На российском VPS запускаешь меню и выбираешь:

```text
3) Установить RU промежуточный узел: локальный SOCKS5 -> FOREIGN
```

Когда скрипт спросит URL FOREIGN узла — вставляешь ссылку, полученную на иностранном сервере.

### 3. На клиенте

В клиенте добавляешь обычный SOCKS5:

```text
Адрес: RU_IP
Порт: 1080
```

После подключения сайты должны видеть IP иностранного VPS.

## Команда меню

Чтобы поставить короткую команду:

```text
8) Установить команду gost-menu
```

После этого меню запускается так:

```bash
gost-menu
```

## Обновление

В меню есть пункт:

```text
9) Обновить меню с GitHub
```

Ссылка уже прописана:

```text
https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh
```

## Удаление

Для полного удаления только GOST-каскада:

```text
10) Полностью удалить GOST cascade
```

Xray, sing-box, 3x-ui, nginx и остальные сервисы не удаляются.
