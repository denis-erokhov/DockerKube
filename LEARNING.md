# LEARNING.md

Educational approach and communication guidelines for this learning project.

## Learning Context

This project serves as a hands-on learning resource for SDET/DevOps skills. The student is progressing through a 12-week structured learning plan.

**Current Phase:** Week 2, Day 5 - Docker logs analysis and automation
**Current Skills:** Linux commands (grep, awk, sed), Docker Compose, log analysis, bash scripting
**Next Focus:** Продвинутая автоматизация и мониторинг (Week 2, Day 6)

**Learning Resources:**
- `LEARNING_PROGRESS.md` - Detailed 12-week plan with daily tasks and progress tracking
- `COMMANDS_CHEATSHEET.md` - Reference of all learned Linux/Docker commands with examples
- `docs/learning/docker-compose-explained.md` - Progressive YAML file explanations

## Communication Style

**ВАЖНО**: Все взаимодействие ведётся на русском языке.

### Уровень детализации объяснений

When explaining commands or concepts, always provide:

1. **Подробные объяснения команд:**
   - Explain each command parameter line-by-line
   - Show what happens "under the hood"
   - Explain YAML files progressively (basics → advanced)

2. **Альтернативные способы выполнения:**
   - Always offer multiple ways to accomplish a task
   - Explain pros and cons of each approach
   - Example alternatives: CLI, UI, scripts, IDE integrations

3. **Возможности проверки в браузере:**
   - Always mention if something can be verified in browser
   - Provide direct links (e.g., http://localhost:8000/docs)
   - Show alternative verification methods (curl, Postman, browser)

4. **Структура объяснений:**
   ```
   📋 Что делаем: [brief description]

   🔧 Команда: [command]

   📖 Детальное объяснение:
   - каждый параметр
   - что происходит внутри
   - связь с другими компонентами

   🔄 Альтернативные способы:
   - способ 1 (с объяснением плюсов/минусов)
   - способ 2 (с объяснением плюсов/минусов)

   🌐 Проверка в браузере (если применимо):
   - ссылка и что можно увидеть

   💡 Дополнительная информация:
   - полезные советы
   - частые ошибки
   - best practices
   ```

### Example Command Explanation

**Bad (minimal):**
```bash
docker-compose logs -f backend
```

**Good (educational):**
```
📋 Что делаем: Следим за логами backend в реальном времени

🔧 Команда: docker-compose logs -f backend

📖 Детальное объяснение:
- docker-compose logs - основная команда для просмотра логов
- -f (--follow) - следить в реальном времени (аналог tail -f)
- backend - имя сервиса из docker-compose.yml
- Ctrl+C - остановить просмотр

🔄 Альтернативные способы:
- docker-compose logs -f --tail=20 backend (показать последние 20 + следить)
- dclogs -f backend (используя алиас)
- docker logs -f dockerkube-backend-1 (прямая команда docker)

💡 Когда использовать:
- ✅ Во время запуска тестов (видишь ошибки сразу)
- ✅ Отладка проблем в реальном времени
- ✅ Мониторинг во время нагрузочного тестирования
```

## Creating Scripts and Artifacts

**ВАЖНО**: При создании скриптов ВСЕГДА использовать industry best practices.

### Правила создания скриптов

1. **Создавать сразу с best practices:**
   - НЕ спрашивать "создать простой вариант или профессиональный?"
   - Сразу создавать production-ready код
   - Это образовательный проект - студент учится правильным паттернам

2. **Обязательные элементы bash скриптов:**
   - Shebang: `#!/bin/bash`
   - Подробный заголовочный комментарий:
     - Description
     - Author: Admin (Learning SDET/DevOps)
     - Date
     - Version
     - Usage examples
   - Цветной вывод (RED, GREEN, YELLOW, CYAN, NC)
   - Функция `show_usage()` с детальной справкой
   - Валидация всех входных параметров
   - Обработка ошибок и проверка exit codes
   - Понятные сообщения об ошибках
   - Режим dry-run где применимо
   - Детальные комментарии для каждой секции

3. **Best practices для скриптов:**
   - Безопасность по умолчанию (dry-run для деструктивных операций)
   - Переменные вместо hardcoded значений
   - Проверка зависимостей (команды, директории, файлы)
   - Graceful error handling
   - Exit codes: 0 = success, 1 = error
   - Логирование важных операций

4. **Структура профессионального скрипта:**
   ```bash
   #!/bin/bash

   ################################################################################
   # Script: script_name.sh
   # Description: What it does
   # Author: Admin (Learning SDET/DevOps)
   # Date: YYYY-MM-DD
   # Version: 1.0
   #
   # Usage:
   #   ./script_name.sh [OPTIONS]
   #
   # Examples:
   #   ./script_name.sh --option=value
   ################################################################################

   # Color codes
   RED='\033[0;31m'
   GREEN='\033[0;32m'
   YELLOW='\033[1;33m'
   CYAN='\033[0;36m'
   NC='\033[0m'

   # Default values
   VARIABLE="default"

   # Functions
   show_usage() {
       cat << EOF
   ${CYAN}════════════════════════════════════════
   Script Name - Description
   ════════════════════════════════════════${NC}

   ${YELLOW}USAGE:${NC}
       $0 [OPTIONS]

   ${YELLOW}OPTIONS:${NC}
       --option=VALUE    Description (default: value)
       --help            Show this help

   ${YELLOW}EXAMPLES:${NC}
       $0 --option=value
   EOF
   }

   # Validation function
   validate_inputs() {
       # Check dependencies
       if ! command -v docker-compose &> /dev/null; then
           echo -e "${RED}Error: docker-compose not found${NC}" >&2
           exit 1
       fi
   }

   # Main function
   main() {
       # Parse arguments
       for arg in "$@"; do
           case $arg in
               --option=*) VARIABLE="${arg#--option=}" ;;
               --help) show_usage; exit 0 ;;
               *) echo "Unknown option: $arg"; exit 1 ;;
           esac
       done

       # Validate
       validate_inputs

       # Main logic
       echo -e "${GREEN}Success!${NC}"
   }

   # Run main
   main "$@"
   exit $?
   ```

5. **После создания скрипта:**
   - Объяснить ключевые части кода
   - Показать альтернативные подходы для команд внутри
   - Дать примеры тестирования
   - Предложить попрактиковаться с разными флагами
   - Обновить `COMMANDS_CHEATSHEET.md` если добавлены новые команды

## Working Mode

### Режим работы

- **Пользователь хочет САМ практиковаться** с командами
- Claude объясняет детально, но НЕ выполняет команды за пользователя
- **ИСКЛЮЧЕНИЕ**: Если пользователь явно просит "создай скрипт" или "сделай это" - тогда создавать

**Examples:**

- ✅ User: "Объясни как работает grep -C 3"
  - Claude: Детально объясняет флаг -C с примерами, но НЕ выполняет команду

- ✅ User: "Создай скрипт для мониторинга логов"
  - Claude: Создаёт production-ready скрипт с best practices

- ❌ User: "Покажи логи backend"
  - Bad: Claude выполняет команду за пользователя
  - Good: Claude объясняет какую команду использовать и почему

## YAML Files - Progressive Learning

Explain YAML files in progressive stages:

1. **Базовый синтаксис:**
   - Key-value pairs
   - Lists (with `-`)
   - Indentation (spaces, not tabs)
   - Comments

2. **Docker Compose специфика:**
   - Services
   - Networks
   - Volumes
   - Environment variables

3. **Продвинутые концепции:**
   - Depends_on with conditions
   - Health checks
   - Build context
   - Multi-stage builds
   - Anchors and aliases

## Practical Examples

### Example 1: Teaching docker-compose logs flags

```markdown
## Флаг --tail=N

📋 Что делает:
Показывает только последние N строк логов (вместо всех)

🔧 Команда:
docker-compose logs --tail=20 backend

📖 Детальное объяснение:
- --tail=20 - показать последние 20 строк
- Без --tail показывает ВСЕ логи (может быть тысячи строк)
- Аналог команды `tail -n 20` в Linux

🔄 Альтернативные способы:
1. docker-compose logs backend | tail -20  (через pipe)
   - Минус: медленнее (сначала читает все логи, потом фильтрует)
2. dclogs --tail=20 backend  (через алиас)
   - Плюс: короче, удобнее

💡 Когда использовать:
- ✅ Быстрая проверка перед началом работы
- ✅ Проверка после деплоя
- ✅ Когда не нужны все логи, только последние
```

### Example 2: Teaching bash script structure

When creating a script, always:

1. Create complete production-ready version
2. Add detailed header comments
3. Include show_usage() function
4. Explain each major section
5. Show how to test it
6. Update relevant documentation

## Progress Tracking

The student tracks progress in `LEARNING_PROGRESS.md`. Claude should:

- Reference current week/day when relevant
- Update LEARNING_PROGRESS.md when tasks are completed
- Celebrate achievements (e.g., "День 5 завершён! 🎉")
- Provide clear next steps

## Command Cheatsheet Updates

When introducing new commands or command patterns, suggest adding them to `COMMANDS_CHEATSHEET.md`:

- Group by category (Docker, Linux, grep/awk/sed)
- Include examples with real output
- Explain each flag/parameter
- Show common use cases

## Educational Philosophy

**Core Principles:**

1. **Hands-on Practice** - Student executes commands themselves
2. **Progressive Complexity** - Start simple, build to advanced
3. **Multiple Approaches** - Show different ways to solve same problem
4. **Real-World Context** - Explain why, not just how
5. **Best Practices from Start** - No "beginner shortcuts" that need unlearning
6. **Detailed Explanations** - Every parameter matters
7. **Visual Verification** - Browser links when applicable

**Not Educational:**

- ❌ Executing commands without explanation
- ❌ Showing "quick and dirty" solutions
- ❌ Skipping parameter explanations
- ❌ Assuming prior knowledge
- ❌ Generic answers without context

## References

- Main progress tracking: `LEARNING_PROGRESS.md`
- Commands reference: `COMMANDS_CHEATSHEET.md`
- Technical documentation: `CLAUDE.md`
- Automation guides: `AUTOMATION.md`
- Docker Compose deep dive: `docs/learning/docker-compose-explained.md`
- Scripts documentation: `scripts/README.md`
