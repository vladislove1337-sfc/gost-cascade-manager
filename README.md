# GOST Cascade Manager

Меню для аварийного каскада на GOST v3:

```text
Клиент -> RU VPS SOCKS5 -> FOREIGN VPS socks5+tls -> Интернет
```

Это отдельная резервная схема. Она не трогает Xray, sing-box, 3x-ui, nginx и существующие конфиги.

## Установка одной командой

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladislove1337-sfc/gost-cascade-manager/main/gost-menu.sh)
```

## Что изменено в этой версии

- Основной рабочий режим заменён на `socks5+tls`.
- Убран проблемный `relay+tls` для базового каскада.
- Добавлен пункт показа ссылки подключения.
- Добавлен QR-code через `qrencode`.
- Добавлен тест каскада через `api.ipify.org`.
- Меню по умолчанию на русском.

## Рекомендуемая настройка

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
socks5+tls://prado:1234567890@194.116.172.222:443
```

После установки выбери:

```text
12) Показать ссылку подключения и QR-code
```

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
