#!/bin/bash
# ============================================================
# vpn-bypass.sh — маршрутизация доменов из белого списка мимо VPN
#
# Использование:
#   sudo ./vpn-bypass.sh          — добавить маршруты
#   sudo ./vpn-bypass.sh --remove — удалить маршруты
#   sudo ./vpn-bypass.sh --status — показать текущие маршруты
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAINS_FILE="$SCRIPT_DIR/bypass-domains.txt"
ROUTE_LOG="$SCRIPT_DIR/.active-routes.log"

# ---- Цвета для вывода ----
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---- Определяем шлюз по умолчанию (не VPN) ----
get_real_gateway() {
    # Ищем шлюз на физических интерфейсах (en0, en1 — Wi-Fi/Ethernet)
    for iface in en0 en1 en2; do
        local gw
        gw=$(networksetup -getinfo "$(networksetup -listallhardwareports | grep -A1 "$iface" | head -1 | awk -F: '{print $2}' | xargs)" 2>/dev/null | grep "^Router:" | awk '{print $2}' || true)
        if [[ -n "$gw" && "$gw" != "none" ]]; then
            echo "$gw"
            return 0
        fi
    done

    # Fallback: берём шлюз из route для en0
    local gw
    gw=$(route -n get -ifscope en0 default 2>/dev/null | grep gateway | awk '{print $2}' || true)
    if [[ -n "$gw" ]]; then
        echo "$gw"
        return 0
    fi

    # Последний fallback
    gw=$(netstat -rn | grep "^default" | grep -v "utun\|tun\|ppp\|ipsec" | head -1 | awk '{print $2}' || true)
    if [[ -n "$gw" ]]; then
        echo "$gw"
        return 0
    fi

    return 1
}

# ---- Резолвим домен в IP-адреса ----
resolve_domain() {
    local domain="$1"
    # dig +short, фильтруем только IPv4
    dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# ---- Добавляем маршруты ----
add_routes() {
    local gateway
    gateway=$(get_real_gateway)

    if [[ -z "$gateway" ]]; then
        echo -e "${RED}Ошибка: не удалось определить основной шлюз.${NC}"
        echo "Убедитесь, что Wi-Fi или Ethernet подключены."
        exit 1
    fi

    echo -e "${GREEN}Основной шлюз (мимо VPN): $gateway${NC}"
    echo ""

    if [[ ! -f "$DOMAINS_FILE" ]]; then
        echo -e "${RED}Файл $DOMAINS_FILE не найден!${NC}"
        exit 1
    fi

    # Очищаем лог предыдущих маршрутов
    > "$ROUTE_LOG"

    local count=0

    while IFS= read -r line; do
        # Пропускаем комментарии и пустые строки
        line=$(echo "$line" | xargs)
        [[ -z "$line" || "$line" == \#* ]] && continue

        local domain="$line"
        echo -e "${YELLOW}→ $domain${NC}"

        local ips
        ips=$(resolve_domain "$domain")

        if [[ -z "$ips" ]]; then
            echo "  (не удалось резолвить, пропускаю)"
            continue
        fi

        while IFS= read -r ip; do
            # Проверяем, нет ли уже такого маршрута
            if route -n get "$ip" 2>/dev/null | grep -q "gateway: $gateway"; then
                echo "  $ip — уже через $gateway, пропускаю"
            else
                route add -host "$ip" "$gateway" >/dev/null 2>&1 && {
                    echo "  $ip ✓"
                    echo "$ip" >> "$ROUTE_LOG"
                    ((count++))
                } || {
                    echo "  $ip — ошибка при добавлении"
                }
            fi
        done <<< "$ips"

    done < "$DOMAINS_FILE"

    echo ""
    echo -e "${GREEN}Готово! Добавлено маршрутов: $count${NC}"
    echo "Для удаления: sudo $0 --remove"
}

# ---- Удаляем маршруты ----
remove_routes() {
    if [[ ! -f "$ROUTE_LOG" ]]; then
        echo "Нет активных маршрутов для удаления."
        exit 0
    fi

    local count=0
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        route delete -host "$ip" >/dev/null 2>&1 && {
            echo -e "  ${RED}✕${NC} $ip удалён"
            ((count++))
        } || true
    done < "$ROUTE_LOG"

    > "$ROUTE_LOG"
    echo ""
    echo -e "${GREEN}Удалено маршрутов: $count${NC}"
}

# ---- Показываем статус ----
show_status() {
    echo -e "${YELLOW}=== Текущий шлюз ===${NC}"
    local gw
    gw=$(get_real_gateway) && echo "Основной шлюз: $gw" || echo "Не удалось определить"

    echo ""
    echo -e "${YELLOW}=== Активные bypass-маршруты ===${NC}"
    if [[ -f "$ROUTE_LOG" && -s "$ROUTE_LOG" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            local info
            info=$(route -n get "$ip" 2>/dev/null | grep "gateway" | awk '{print $2}')
            echo "  $ip → gateway $info"
        done < "$ROUTE_LOG"
    else
        echo "  (нет активных маршрутов)"
    fi
}

# ---- Main ----
case "${1:-}" in
    --remove|-r)
        remove_routes
        ;;
    --status|-s)
        show_status
        ;;
    --help|-h)
        echo "Использование:"
        echo "  sudo $0            — добавить маршруты (домены из bypass-domains.txt)"
        echo "  sudo $0 --remove   — удалить все bypass-маршруты"
        echo "  sudo $0 --status   — показать текущее состояние"
        ;;
    *)
        add_routes
        ;;
esac
