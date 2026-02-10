# VPN Bypass — белый список сайтов мимо VPN

Скрипт для macOS, который позволяет указанным доменам ходить **напрямую**,
минуя любой подключённый VPN (WireGuard, OpenVPN, и т.д.).

Работает с **любым** VPN-клиентом — не зависит от конкретного приложения.

---

## Установка

1. Скопируйте папку `vpn-bypass` куда удобно, например в домашнюю:

```bash
cp -r vpn-bypass ~/vpn-bypass
```

2. Сделайте скрипт исполняемым:

```bash
chmod +x ~/vpn-bypass/vpn-bypass.sh
```

---

## Использование

### Добавить домены в белый список

Отредактируйте файл `bypass-domains.txt` — по одному домену на строку:

```
pochta.ru
sberbank.ru
gosuslugi.ru
```

Поддомены (например `tracking.pochta.ru`) резолвятся автоматически —
**но их нужно вписать явно**, если они резолвятся на другой IP.
Для надёжности добавляйте и основной домен, и ключевые поддомены:

```
pochta.ru
tracking.pochta.ru
www.pochta.ru
```

### Включить bypass (после подключения VPN)

```bash
sudo ~/vpn-bypass/vpn-bypass.sh
```

### Посмотреть статус

```bash
sudo ~/vpn-bypass/vpn-bypass.sh --status
```

### Отключить bypass

```bash
sudo ~/vpn-bypass/vpn-bypass.sh --remove
```

---

## Автозапуск при подключении VPN (опционально)

Если хотите, чтобы скрипт запускался автоматически при смене сети
(т.е. при подключении/отключении VPN), создайте файл:

`~/Library/LaunchAgents/com.user.vpn-bypass.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.vpn-bypass</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/ВАШ_ЮЗЕРНЕЙМ/vpn-bypass/vpn-bypass.sh</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/etc/resolv.conf</string>
        <string>/Library/Preferences/SystemConfiguration</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

**Важно:** замените `ВАШ_ЮЗЕРНЕЙМ` на ваше имя пользователя macOS.

Затем:

```bash
launchctl load ~/Library/LaunchAgents/com.user.vpn-bypass.plist
```

> ⚠️ Для автозапуска с `sudo` потребуется настроить `sudoers`
> (разрешить `route` без пароля) — см. раздел ниже.

### Разрешить route без пароля

```bash
sudo visudo
```

Добавьте строку (замените `ВАШ_ЮЗЕРНЕЙМ`):

```
ВАШ_ЮЗЕРНЕЙМ ALL=(ALL) NOPASSWD: /sbin/route
```

---

## Ограничения

- Скрипт работает на уровне IP, а не доменов. Если сайт сменит IP
  (CDN, балансировка), нужно перезапустить скрипт.
- Для сайтов за CDN (Cloudflare и т.п.) один IP может обслуживать
  много доменов — это нормально и не вызывает проблем.
- Скрипт нужно запускать **после** подключения VPN (или настроить автозапуск).

---

## Структура файлов

```
vpn-bypass/
├── bypass-domains.txt   ← ваш белый список (редактируйте)
├── vpn-bypass.sh        ← основной скрипт
├── .active-routes.log   ← создаётся автоматически (для --remove)
└── README.md            ← эта инструкция
```
