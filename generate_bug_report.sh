  #!/bin/bash

  # ==========================================
  # Bug Report Generator для DockerKube
  # Автор: Admin
  # Дата создания: 2025-12-22
  # ==========================================

  # Цвета для вывода (опционально)
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color

  echo -e "${BLUE}🔍 Генерация Bug Report...${NC}"

  # Имя выходного файла
  OUTPUT_FILE="bug_report_$(date +%Y%m%d_%H%M%S).txt"

  # Создаём header отчёта
  echo "===========================================" > "$OUTPUT_FILE"
  echo "BUG REPORT: API Errors Analysis" >> "$OUTPUT_FILE"
  echo "===========================================" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Дата анализа: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
  echo "Анализировал: Admin" >> "$OUTPUT_FILE"
  echo "Окружение: DockerKube Backend (FastAPI + PostgreSQL)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  # 1. Описание проблемы
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "1. КРАТКОЕ ОПИСАНИЕ ПРОБЛЕМЫ" >> "$OUTPUT_FILE"
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Обнаружены HTTP ошибки в логах backend API." >> "$OUTPUT_FILE"
  echo "Ошибки связаны с валидацией данных (422) и конфликтами (400, 404)." >> "$OUTPUT_FILE"                                                                                           
  echo "" >> "$OUTPUT_FILE"

  echo -e "${BLUE}📊 Собираю статистику ошибок...${NC}"

  # 2. Статистика
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "2. СТАТИСТИКА ОШИБОК" >> "$OUTPUT_FILE"
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  docker-compose logs backend | grep -oE 'HTTP/1\.1" [4-5][0-9]{2}' | awk '{print $2}' | sort | uniq -c >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  # Подсчёт конкретных кодов
  echo "Детальная статистика:" >> "$OUTPUT_FILE"
  echo "- Ошибок 422: $(docker-compose logs backend | grep '422' | wc -l)" >> "$OUTPUT_FILE"
  echo "- Ошибок 400: $(docker-compose logs backend | grep '400' | wc -l)" >> "$OUTPUT_FILE"
  echo "- Ошибок 404: $(docker-compose logs backend | grep '404' | wc -l)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  echo -e "${BLUE}📝 Добавляю примеры ошибок...${NC}"

  # 3. Примеры ошибок 422
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "3. ПРИМЕРЫ ОШИБОК 422 (Validation Error)" >> "$OUTPUT_FILE"
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  docker-compose logs backend | grep "422" | head -3 >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  # 4. Примеры ошибок 400
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "4. ПРИМЕРЫ ОШИБОК 400 (Bad Request)" >> "$OUTPUT_FILE"
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  docker-compose logs backend | grep "400" | head -3 >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  echo -e "${BLUE}🌐 Анализирую IP адреса...${NC}"

  # 5. IP статистика
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "5. АНАЛИЗ IP АДРЕСОВ" >> "$OUTPUT_FILE"
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Топ-5 IP адресов по количеству запросов:" >> "$OUTPUT_FILE"
  docker-compose logs backend | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -rn | head -5 >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Всего уникальных IP: $(docker-compose logs backend | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u | wc -l)" >> "$OUTPUT_FILE"                                            
  echo "" >> "$OUTPUT_FILE"

  # 6. Временной диапазон
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "6. ВРЕМЕННОЙ ДИАПАЗОН ОШИБОК" >> "$OUTPUT_FILE"
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Первая ошибка 422:" >> "$OUTPUT_FILE"
  docker-compose logs backend | grep "422" | head -1 >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "Последняя ошибка 422:" >> "$OUTPUT_FILE"
  docker-compose logs backend | grep "422" | tail -1 >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  # 7. Рекомендации
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "7. РЕКОМЕНДАЦИИ ПО ИСПРАВЛЕНИЮ" >> "$OUTPUT_FILE"
  echo "-------------------------------------------" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "1. Проверить валидацию email на стороне backend" >> "$OUTPUT_FILE"
  echo "2. Добавить более детальные сообщения об ошибках для клиента" >> "$OUTPUT_FILE"
  echo "3. Логировать тело запроса для ошибок 422 (улучшить debugging)" >> "$OUTPUT_FILE"
  echo "4. Настроить мониторинг на threshold ошибок 4xx (>20% = alert)" >> "$OUTPUT_FILE"
  echo "5. Проверить источник 404 ошибок - возможно неправильные URL" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "===========================================" >> "$OUTPUT_FILE"
  echo "КОНЕЦ ОТЧЁТА" >> "$OUTPUT_FILE"
  echo "===========================================" >> "$OUTPUT_FILE"

  echo -e "${GREEN}✅ Bug report успешно создан: $OUTPUT_FILE${NC}"
  echo ""
  echo "Для просмотра выполните:"
  echo "  cat $OUTPUT_FILE"
  echo "или"
  echo "  less $OUTPUT_FILE"
