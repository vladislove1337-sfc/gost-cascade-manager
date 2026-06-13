# GOST Cascade Manager

Менеджер для настройки резервного каскада GOST.

Схема работы:

```
Клиент
 ↓
RU VPS (SOCKS5)
 ↓
GOST socks5+tls
 ↓
FOREIGN VPS
 ↓
Интернет
```

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

## 🚀 Запуск меню после установки

После первой установки можно открыть менеджер командой:

```bash
gost-menu
```

Если команда отсутствует — откройте меню и выберите:

```
8) Установить команду gost-menu
```

После этого запускать менеджер можно из любого места:

```bash
gost-menu
```

## Возможности

- установка FOREIGN сервера
- установка RU каскадного сервера
- SOCKS5 + TLS каскад
- просмотр статуса
- просмотр логов
- перезапуск службы
- обновление с GitHub
- удаление GOST
- генерация ссылки подключения
- QR-code для клиента

## Проверка

```bash
curl -x socks5h://USER:PASSWORD@127.0.0.1:1080 https://api.ipify.org
```

Должен отображаться IP FOREIGN VPS.
