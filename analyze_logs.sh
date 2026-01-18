#!/bin/bash
# Улучшенный скрипт анализа логов

echo "================================================"
echo "  📊 АНАЛИЗ ЛОГОВ BACKEND"
echo "  Дата: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"
echo

# 1. Общее количество HTTP запросов
TOTAL_REQUESTS=$(docker-compose logs --no-log-prefix backend | grep -c 'HTTP/1.1')
echo "📈 Всего HTTP запросов: $TOTAL_REQUESTS"
echo

# 2. Статистика по HTTP кодам
echo "📊 Статистика кодов ответов:"
docker-compose logs --no-log-prefix backend | \
  grep -oE 'HTTP/1\.1" [0-9]{3}' | \
  awk '{print $2}' | \
  sort | uniq -c | \
  awk '{printf "  %3s: %s запросов\n", $2, $1}'
echo

# 3. Только ошибки 4xx и 5xx
ERROR_COUNT=$(docker-compose logs --no-log-prefix backend | grep -cE 'HTTP/1\.1" [4-5][0-9]{2}')
echo "❌ Всего ошибок (4xx, 5xx): $ERROR_COUNT"
echo

# 4. Детализация ошибок
echo "🔍 Детализация ошибок:"
docker-compose logs --no-log-prefix backend | \
  grep -oE 'HTTP/1\.1" [4-5][0-9]{2}' | \
  awk '{print $2}' | \
  sort | uniq -c | \
  awk '{printf "  %s: %s раз\n", $2, $1}'
echo

# 5. Примеры последних ошибок
echo "📋 Последние 5 ошибок:"
docker-compose logs --no-log-prefix backend | \
  grep -E 'HTTP/1\.1" [4-5][0-9]{2}' | \
  tail -5 | \
  sed 's/^/  /'
echo

# 6. Процент успешных запросов
if [ $TOTAL_REQUESTS -gt 0 ]; then
  SUCCESS_COUNT=$((TOTAL_REQUESTS - ERROR_COUNT))
  SUCCESS_PERCENT=$((SUCCESS_COUNT * 100 / TOTAL_REQUESTS))
  echo "✅ Успешных запросов: $SUCCESS_COUNT ($SUCCESS_PERCENT%)"
  echo "❌ Ошибочных запросов: $ERROR_COUNT ($((100 - SUCCESS_PERCENT))%)"
fi
echo

echo "================================================"
echo "✅ Анализ завершён"
echo "================================================"
