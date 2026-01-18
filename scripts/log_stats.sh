#!/bin/bash

################################################################################
# Script: log_stats.sh
# Description: Comprehensive log statistics using awk, sed, jq combinations
#              Финальное задание Недели 4 - объединение всех изученных инструментов
#
# Author: Denis E. (Learning SDET/DevOps)
# Date: 2026-01-11
# Version: 1.0
#
# Tools used:
#   - awk: column extraction, filtering, arrays, statistics
#   - sed: text transformation, cleanup
#   - jq: JSON parsing (docker inspect)
#   - grep: pattern matching
#   - sort/uniq: counting and sorting
#
# Usage:
#   ./log_stats.sh [OPTIONS]
#
# Examples:
#   ./log_stats.sh                      # Full report for all services
#   ./log_stats.sh --service=backend    # Report for backend only
#   ./log_stats.sh --top=5              # Show top 5 instead of 10
#   ./log_stats.sh --output=report.txt  # Save to file
#   ./log_stats.sh --json               # Output in JSON format
################################################################################

# =============================================================================
# СЕКЦИЯ 1: Цветовые коды и константы
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'  # No Color

# Default values
SERVICE="backend"
TOP_COUNT=10
OUTPUT_FILE=""
JSON_OUTPUT=false
LINES=1000

# =============================================================================
# СЕКЦИЯ 2: Функция справки
# =============================================================================

show_usage() {
    cat << EOF
${CYAN}════════════════════════════════════════════════════════════════════════════════
  LOG STATS - Комплексный анализ логов Docker
  Финальное задание Недели 4: awk + sed + jq + grep
════════════════════════════════════════════════════════════════════════════════${NC}

${YELLOW}ИСПОЛЬЗОВАНИЕ:${NC}
    $0 [OPTIONS]

${YELLOW}ОПЦИИ:${NC}
    --service=NAME    Сервис для анализа (default: backend)
                      Доступные: backend, postgres, all
    --top=N           Количество записей в топах (default: 10)
    --lines=N         Количество строк логов для анализа (default: 1000)
    --output=FILE     Сохранить отчёт в файл
    --json            Вывод в формате JSON
    --help            Показать эту справку

${YELLOW}ПРИМЕРЫ:${NC}
    ${GREEN}# Полный отчёт по backend${NC}
    $0

    ${GREEN}# Топ-5 по всем сервисам${NC}
    $0 --service=all --top=5

    ${GREEN}# Сохранить отчёт в файл${NC}
    $0 --output=logs/analysis/stats/daily_report.txt

    ${GREEN}# JSON формат для автоматизации${NC}
    $0 --json --service=backend

${YELLOW}ЧТО АНАЛИЗИРУЕТ:${NC}
    📊 HTTP коды ответов (статистика и распределение)
    🔴 Топ ошибок (4xx, 5xx) с примерами
    🌐 Топ IP-адресов по количеству запросов
    📈 Топ эндпоинтов по популярности
    🐳 Информация о Docker контейнерах (через jq)
    ⏱️  Временной анализ (первый/последний запрос)

${YELLOW}ИНСТРУМЕНТЫ:${NC}
    awk   - извлечение колонок, подсчёт статистики
    sed   - очистка и трансформация текста
    jq    - парсинг JSON (docker inspect)
    grep  - поиск паттернов
    sort  - сортировка
    uniq  - подсчёт уникальных значений

EOF
}

# =============================================================================
# СЕКЦИЯ 3: Вспомогательные функции
# =============================================================================

# Печать заголовка секции
print_header() {
    local title="$1"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $title${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Печать подзаголовка
print_subheader() {
    local title="$1"
    echo ""
    echo -e "${YELLOW}▸ $title${NC}"
    echo -e "${YELLOW}─────────────────────────────────────────${NC}"
}

# Проверка наличия команды
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ Ошибка: команда '$1' не найдена${NC}" >&2
        return 1
    fi
    return 0
}

# Получение логов (с кэшированием в переменную)
get_logs() {
    local service="$1"
    local lines="$2"

    if [[ "$service" == "all" ]]; then
        docker-compose logs --no-color --tail="$lines" 2>/dev/null
    else
        docker-compose logs --no-color --tail="$lines" "$service" 2>/dev/null
    fi
}

# =============================================================================
# СЕКЦИЯ 4: Валидация
# =============================================================================

validate_environment() {
    local errors=0

    echo -e "${CYAN}🔍 Проверка окружения...${NC}"

    # Проверка необходимых команд
    for cmd in docker-compose awk sed grep sort uniq; do
        if check_command "$cmd"; then
            echo -e "  ${GREEN}✓${NC} $cmd"
        else
            ((errors++))
        fi
    done

    # jq опционален, но полезен
    if check_command "jq"; then
        echo -e "  ${GREEN}✓${NC} jq"
        JQ_AVAILABLE=true
    else
        echo -e "  ${YELLOW}⚠${NC} jq (не установлен - JSON анализ будет ограничен)"
        JQ_AVAILABLE=false
    fi

    # Проверка что docker-compose работает
    if ! docker-compose ps &> /dev/null; then
        echo -e "${RED}✗ Ошибка: docker-compose не может подключиться к Docker${NC}" >&2
        ((errors++))
    else
        echo -e "  ${GREEN}✓${NC} Docker доступен"
    fi

    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}✗ Найдено ошибок: $errors${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Все проверки пройдены${NC}"
    return 0
}

# =============================================================================
# СЕКЦИЯ 5: Функции анализа (awk, sed, grep)
# =============================================================================

# Статистика HTTP кодов (awk)
analyze_http_codes() {
    local logs="$1"

    print_subheader "📊 Статистика HTTP кодов"

    # Извлекаем HTTP коды с помощью awk
    # Паттерн: "HTTP/1.1" 200 или просто " 200 " после метода
    echo "$logs" | \
        grep -oE 'HTTP/1\.[01]" [0-9]{3}' | \
        awk '{print $2}' | \
        sort | \
        uniq -c | \
        sort -rn | \
        awk -v green="$GREEN" -v yellow="$YELLOW" -v red="$RED" -v nc="$NC" '
        BEGIN {
            total = 0
        }
        {
            count = $1
            code = $2
            total += count
            codes[code] = count
        }
        END {
            printf "\n  %-10s %-10s %-10s %s\n", "Код", "Кол-во", "Процент", "Статус"
            printf "  %-10s %-10s %-10s %s\n", "───", "──────", "───────", "──────"

            # Сортируем по коду
            n = asorti(codes, sorted_codes)
            for (i = 1; i <= n; i++) {
                code = sorted_codes[i]
                count = codes[code]
                pct = (count / total) * 100

                # Определяем цвет и статус
                if (code >= 200 && code < 300) {
                    color = green
                    status = "OK"
                } else if (code >= 300 && code < 400) {
                    color = yellow
                    status = "Redirect"
                } else if (code >= 400 && code < 500) {
                    color = yellow
                    status = "Client Error"
                } else if (code >= 500) {
                    color = red
                    status = "Server Error"
                } else {
                    color = nc
                    status = "Unknown"
                }

                printf "  %s%-10s%s %-10d %5.1f%%     %s\n", color, code, nc, count, pct, status
            }
            printf "\n  %s%-10s%s %-10d %s\n", green, "ИТОГО:", nc, total, "запросов"
        }'
}

# Топ ошибок с примерами (grep + awk + sed)
analyze_top_errors() {
    local logs="$1"
    local top_n="$2"

    print_subheader "🔴 Топ-$top_n ошибок (4xx, 5xx)"

    # Находим строки с ошибками и группируем
    local error_stats=$(echo "$logs" | \
        grep -E 'HTTP/1\.[01]" [45][0-9]{2}' | \
        sed 's/^[^|]*| //' | \
        grep -oE '"(GET|POST|PUT|DELETE|PATCH) [^"]+' | \
        sed 's/"//g' | \
        sort | \
        uniq -c | \
        sort -rn | \
        head -n "$top_n")

    if [[ -z "$error_stats" ]]; then
        echo -e "  ${GREEN}✓ Ошибок не найдено!${NC}"
        return
    fi

    echo ""
    echo "  Кол-во  Метод    Endpoint"
    echo "  ──────  ─────    ────────"
    echo "$error_stats" | awk '{printf "  %-6d  %-8s %s\n", $1, $2, $3}'

    # Показываем примеры последних ошибок
    echo ""
    echo -e "  ${YELLOW}Последние 3 ошибки:${NC}"
    echo "$logs" | \
        grep -E 'HTTP/1\.[01]" [45][0-9]{2}' | \
        tail -3 | \
        sed 's/^/    /'
}

# Топ IP-адресов (awk)
analyze_top_ips() {
    local logs="$1"
    local top_n="$2"

    print_subheader "🌐 Топ-$top_n IP-адресов"

    echo ""
    echo "  Запросов  IP-адрес"
    echo "  ────────  ────────"

    # Извлекаем IP адреса с помощью awk
    echo "$logs" | \
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
        sort | \
        uniq -c | \
        sort -rn | \
        head -n "$top_n" | \
        awk '{printf "  %-8d  %s\n", $1, $2}'
}

# Топ эндпоинтов (awk + sed)
analyze_top_endpoints() {
    local logs="$1"
    local top_n="$2"

    print_subheader "📈 Топ-$top_n эндпоинтов"

    echo ""
    echo "  Запросов  Метод    Endpoint"
    echo "  ────────  ─────    ────────"

    # Извлекаем метод и путь
    echo "$logs" | \
        grep -oE '"(GET|POST|PUT|DELETE|PATCH) [^"]+' | \
        sed 's/"//g' | \
        awk '{print $1, $2}' | \
        sort | \
        uniq -c | \
        sort -rn | \
        head -n "$top_n" | \
        awk '{printf "  %-8d  %-8s %s\n", $1, $2, $3}'
}

# Временной анализ (awk + sed)
analyze_time_range() {
    local logs="$1"

    print_subheader "⏱️  Временной диапазон"

    # Извлекаем временные метки
    local first_time=$(echo "$logs" | \
        grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | \
        head -1)

    local last_time=$(echo "$logs" | \
        grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | \
        tail -1)

    if [[ -n "$first_time" && -n "$last_time" ]]; then
        # Форматируем для читаемости
        local first_formatted=$(echo "$first_time" | sed 's/T/ /')
        local last_formatted=$(echo "$last_time" | sed 's/T/ /')

        echo ""
        echo -e "  Первый запрос:    ${GREEN}$first_formatted${NC}"
        echo -e "  Последний запрос: ${GREEN}$last_formatted${NC}"
    else
        echo -e "  ${YELLOW}Временные метки не найдены${NC}"
    fi
}

# =============================================================================
# СЕКЦИЯ 6: Docker анализ (jq)
# =============================================================================

analyze_containers() {
    print_subheader "🐳 Информация о контейнерах (docker + jq)"

    if [[ "$JQ_AVAILABLE" != "true" ]]; then
        echo -e "  ${YELLOW}⚠ jq не установлен - используем базовый вывод${NC}"
        echo ""
        docker-compose ps
        return
    fi

    echo ""

    # Получаем список контейнеров
    local containers=$(docker-compose ps -q 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "  ${YELLOW}Нет запущенных контейнеров${NC}"
        return
    fi

    echo "  Контейнер              Статус         CPU         Memory      Image"
    echo "  ─────────              ──────         ───         ──────      ─────"

    for container_id in $containers; do
        # Используем docker inspect + jq для извлечения данных
        local info=$(docker inspect "$container_id" 2>/dev/null | jq -r '
            .[0] |
            "\(.Name | ltrimstr("/"))|\(.State.Status)|\(.Config.Image)"
        ')

        if [[ -n "$info" ]]; then
            local name=$(echo "$info" | cut -d'|' -f1)
            local status=$(echo "$info" | cut -d'|' -f2)
            local image=$(echo "$info" | cut -d'|' -f3)

            # Получаем stats (CPU/Memory)
            local stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" "$container_id" 2>/dev/null)
            local cpu=$(echo "$stats" | cut -d'|' -f1)
            local mem=$(echo "$stats" | cut -d'|' -f2 | cut -d'/' -f1)

            # Цвет статуса
            local status_color="$GREEN"
            [[ "$status" != "running" ]] && status_color="$RED"

            printf "  %-22s ${status_color}%-14s${NC} %-11s %-11s %s\n" \
                "$name" "$status" "$cpu" "$mem" "$image"
        fi
    done

    # Дополнительная информация через jq
    echo ""
    echo -e "  ${CYAN}Переменные окружения (backend):${NC}"
    docker inspect dockerkube-backend-1 2>/dev/null | jq -r '
        .[0].Config.Env[] |
        select(startswith("DATABASE") or startswith("API") or startswith("PYTHON")) |
        "    " + .
    ' 2>/dev/null || echo "    (контейнер не найден)"
}

# =============================================================================
# СЕКЦИЯ 7: Генерация итогового отчёта
# =============================================================================

generate_summary() {
    local logs="$1"

    print_header "📋 ИТОГОВАЯ СВОДКА"

    # Подсчёт основных метрик
    local total_lines=$(echo "$logs" | wc -l)
    local total_requests=$(echo "$logs" | grep -c 'HTTP/1\.[01]"' || echo "0")
    local total_errors=$(echo "$logs" | grep -cE 'HTTP/1\.[01]" [45][0-9]{2}' || echo "0")
    local unique_ips=$(echo "$logs" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u | wc -l)

    # Вычисляем процент ошибок
    local error_rate=0
    if [[ $total_requests -gt 0 ]]; then
        error_rate=$(awk "BEGIN {printf \"%.1f\", ($total_errors / $total_requests) * 100}")
    fi

    # Определяем цвет для error rate
    local rate_color="$GREEN"
    if (( $(echo "$error_rate > 5" | bc -l 2>/dev/null || echo "0") )); then
        rate_color="$YELLOW"
    fi
    if (( $(echo "$error_rate > 10" | bc -l 2>/dev/null || echo "0") )); then
        rate_color="$RED"
    fi

    echo ""
    echo "  ┌─────────────────────────────────────────────────┐"
    echo "  │                                                 │"
    printf "  │  📊 Всего строк логов:     %-20s │\n" "$total_lines"
    printf "  │  📡 HTTP запросов:         %-20s │\n" "$total_requests"
    printf "  │  ❌ Ошибок (4xx/5xx):      %-20s │\n" "$total_errors"
    echo -e "  │  📈 Error Rate:            ${rate_color}${error_rate}%${NC}                   │"
    printf "  │  🌐 Уникальных IP:         %-20s │\n" "$unique_ips"
    echo "  │                                                 │"
    echo "  └─────────────────────────────────────────────────┘"

    # Рекомендации на основе метрик
    echo ""
    echo -e "  ${CYAN}Рекомендации:${NC}"

    if (( $(echo "$error_rate > 10" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "  ${RED}⚠ Высокий error rate ($error_rate%)! Требуется расследование.${NC}"
        echo -e "    Используй: ${YELLOW}./scripts/error_patterns.sh --service=backend --report${NC}"
    elif (( $(echo "$error_rate > 5" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "  ${YELLOW}⚠ Повышенный error rate ($error_rate%). Рекомендуется проверка.${NC}"
    else
        echo -e "  ${GREEN}✓ Error rate в норме ($error_rate%)${NC}"
    fi
}

# =============================================================================
# СЕКЦИЯ 8: JSON вывод
# =============================================================================

generate_json_output() {
    local logs="$1"

    # Подсчёт метрик
    local total_requests=$(echo "$logs" | grep -c 'HTTP/1\.[01]"' || echo "0")
    local total_errors=$(echo "$logs" | grep -cE 'HTTP/1\.[01]" [45][0-9]{2}' || echo "0")
    local unique_ips=$(echo "$logs" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u | wc -l)

    local error_rate=0
    if [[ $total_requests -gt 0 ]]; then
        error_rate=$(awk "BEGIN {printf \"%.2f\", ($total_errors / $total_requests) * 100}")
    fi

    # HTTP коды в JSON
    local http_codes=$(echo "$logs" | \
        grep -oE 'HTTP/1\.[01]" [0-9]{3}' | \
        awk '{print $2}' | \
        sort | \
        uniq -c | \
        awk 'BEGIN {printf "{"}
             NR>1 {printf ", "}
             {printf "\"%s\": %d", $2, $1}
             END {printf "}"}')

    # Топ IP
    local top_ips=$(echo "$logs" | \
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
        sort | uniq -c | sort -rn | head -5 | \
        awk 'BEGIN {printf "["}
             NR>1 {printf ", "}
             {printf "{\"ip\": \"%s\", \"count\": %d}", $2, $1}
             END {printf "]"}')

    # Формируем JSON
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "service": "$SERVICE",
  "metrics": {
    "total_requests": $total_requests,
    "total_errors": $total_errors,
    "error_rate": $error_rate,
    "unique_ips": $unique_ips
  },
  "http_codes": $http_codes,
  "top_ips": $top_ips
}
EOF
}

# =============================================================================
# СЕКЦИЯ 9: Главная функция
# =============================================================================

main() {
    # Парсинг аргументов
    for arg in "$@"; do
        case $arg in
            --service=*)
                SERVICE="${arg#--service=}"
                ;;
            --top=*)
                TOP_COUNT="${arg#--top=}"
                ;;
            --lines=*)
                LINES="${arg#--lines=}"
                ;;
            --output=*)
                OUTPUT_FILE="${arg#--output=}"
                ;;
            --json)
                JSON_OUTPUT=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Неизвестная опция: $arg${NC}"
                echo "Используй --help для справки"
                exit 1
                ;;
        esac
    done

    # Если JSON вывод - минимальная валидация и сразу данные
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        local logs=$(get_logs "$SERVICE" "$LINES")
        if [[ -z "$logs" ]]; then
            echo '{"error": "No logs available"}'
            exit 1
        fi
        generate_json_output "$logs"
        exit 0
    fi

    # Валидация окружения
    if ! validate_environment; then
        exit 1
    fi

    # Заголовок отчёта
    print_header "📊 LOG STATS REPORT"
    echo ""
    echo -e "  Сервис:     ${GREEN}$SERVICE${NC}"
    echo -e "  Строк:      ${GREEN}$LINES${NC}"
    echo -e "  Топ:        ${GREEN}$TOP_COUNT${NC}"
    echo -e "  Время:      ${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"

    # Получаем логи
    echo ""
    echo -e "${CYAN}📥 Получение логов...${NC}"
    local logs=$(get_logs "$SERVICE" "$LINES")

    if [[ -z "$logs" ]]; then
        echo -e "${RED}✗ Логи не найдены. Проверь что контейнеры запущены: dcps${NC}"
        exit 1
    fi

    local log_lines=$(echo "$logs" | wc -l)
    echo -e "${GREEN}✓ Получено $log_lines строк${NC}"

    # Запускаем анализ
    # Функция для вывода (в файл или stdout)
    run_analysis() {
        analyze_http_codes "$logs"
        analyze_top_errors "$logs" "$TOP_COUNT"
        analyze_top_ips "$logs" "$TOP_COUNT"
        analyze_top_endpoints "$logs" "$TOP_COUNT"
        analyze_time_range "$logs"
        analyze_containers
        generate_summary "$logs"

        echo ""
        print_header "✅ АНАЛИЗ ЗАВЕРШЁН"
        echo ""
        echo -e "  Использованные инструменты:"
        echo -e "    ${CYAN}awk${NC}  - извлечение колонок, подсчёт статистики"
        echo -e "    ${CYAN}sed${NC}  - очистка текста, замены"
        echo -e "    ${CYAN}jq${NC}   - парсинг JSON (docker inspect)"
        echo -e "    ${CYAN}grep${NC} - поиск паттернов"
        echo ""
    }

    # Вывод в файл или stdout
    if [[ -n "$OUTPUT_FILE" ]]; then
        # Создаём директорию если нужно
        mkdir -p "$(dirname "$OUTPUT_FILE")"

        # Убираем цвета для файла
        run_analysis | sed 's/\x1b\[[0-9;]*m//g' > "$OUTPUT_FILE"

        echo -e "${GREEN}✓ Отчёт сохранён в: $OUTPUT_FILE${NC}"
    else
        run_analysis
    fi
}

# =============================================================================
# ЗАПУСК
# =============================================================================

main "$@"
exit $?
