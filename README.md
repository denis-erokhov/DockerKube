# User Management API - Учебный проект для автотестирования

Полнофункциональный проект для изучения автоматизации тестирования REST API с использованием Python, Docker и Kubernetes.

## Описание проекта

Это реалистичный учебный проект, демонстрирующий:
- REST API на FastAPI с CRUD операциями
- Автотесты на pytest с фикстурами и параметризацией
- Контейнеризацию с Docker и Docker Compose
- Развёртывание в Kubernetes
- Запуск автотестов в Job'ах Kubernetes

**Backend API** предоставляет CRUD операции для управления пользователями с валидацией, обработкой ошибок и Swagger документацией.

**Автотесты** покрывают позитивные сценарии, негативные кейсы, граничные случаи и включают подробное логирование.

## Технологический стек

- **Python 3.11**
- **FastAPI** - современный веб-фреймворк
- **PostgreSQL** - база данных
- **SQLAlchemy** - ORM для работы с БД
- **Pytest** - фреймворк для автотестов
- **Requests** - HTTP клиент для тестов
- **Docker & Docker Compose** - контейнеризация
- **Kubernetes** - оркестрация контейнеров

## Структура проекта

```
DockerKube/
├── backend/                    # Backend приложение (FastAPI)
│   ├── app/
│   │   ├── main.py            # API endpoints
│   │   ├── models.py          # SQLAlchemy модели
│   │   ├── schemas.py         # Pydantic схемы
│   │   ├── crud.py            # CRUD операции
│   │   └── database.py        # Подключение к БД
│   └── requirements.txt
│
├── tests/                      # Автотесты
│   ├── conftest.py            # Pytest фикстуры
│   ├── test_users_crud.py     # Позитивные тесты
│   ├── test_users_negative.py # Негативные тесты
│   ├── test_users_edge_cases.py
│   ├── utils/
│   │   ├── logger.py          # Логирование HTTP
│   │   └── helpers.py         # Вспомогательные функции
│   └── requirements.txt
│
├── docker/                     # Docker конфигурация
│   ├── backend.Dockerfile
│   └── tests.Dockerfile
│
├── k8s/                        # Kubernetes манифесты
│   ├── namespace.yaml
│   ├── postgres-*.yaml
│   ├── backend-*.yaml
│   └── tests-job.yaml
│
├── docker-compose.yml          # Локальный запуск
├── pytest.ini                  # Конфигурация pytest
├── .env.example                # Пример переменных окружения
├── .gitignore
└── README.md
```

## Быстрый старт

### Предварительные требования

- Docker Desktop или Docker Engine (версия 20.10+)
- Docker Compose (версия 2.0+)
- Git
- (Опционально) Kubernetes кластер (Minikube, Kind, или cloud)

### 1. Клонирование и подготовка

```bash
# Перейдите в директорию проекта
cd DockerKube

# Создайте .env файл (опционально)
cp .env.example .env
```

### 2. Запуск всего стека локально

```bash
# Запустить все сервисы (PostgreSQL + Backend + Tests)
docker-compose up --build

# Что происходит:
# 1. Собираются Docker образы для backend и tests
# 2. Запускается PostgreSQL
# 3. Запускается Backend API (ждёт готовности БД)
# 4. Запускаются автотесты (ждут готовности API)
```

**Результат:** Вы увидите логи запуска всех сервисов, а затем выполнение тестов.

### 3. Проверка работы API

Откройте в браузере:
- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc
- **Health check:** http://localhost:8000/

## Работа с проектом

### Запуск отдельных компонентов

```bash
# Только PostgreSQL и Backend (без тестов)
docker-compose up postgres backend

# Только тесты (если backend уже запущен)
docker-compose up tests

# Запуск в фоновом режиме
docker-compose up -d

# Остановка всех сервисов
docker-compose down

# Остановка и удаление volumes (очистка БД)
docker-compose down -v
```

### Просмотр логов

```bash
# Логи всех сервисов
docker-compose logs

# Логи конкретного сервиса
docker-compose logs backend
docker-compose logs tests
docker-compose logs postgres

# Следить за логами в реальном времени
docker-compose logs -f backend

# Последние 50 строк логов
docker-compose logs --tail=50 tests
```

### Интерактивная работа с контейнерами

```bash
# Войти в контейнер backend
docker-compose exec backend sh

# Выполнить команду в контейнере
docker-compose exec backend ls -la

# Перезапустить конкретный сервис
docker-compose restart backend

# Проверить статус сервисов
docker-compose ps
```

## Запуск автотестов

### Локально через Docker Compose

```bash
# Запустить все тесты
docker-compose up tests

# Запустить с пересборкой образа
docker-compose up --build tests

# Запустить конкретный тестовый файл
docker-compose run tests pytest -v test_users_crud.py

# Запустить тесты с маркером
docker-compose run tests pytest -v -m crud

# Запустить конкретный тест
docker-compose run tests pytest -v -k test_create_user_success

# Параллельный запуск тестов (требует pytest-xdist)
docker-compose run tests pytest -v -n auto
```

### Локально без Docker (для разработки)

```bash
# Установите Python 3.11
# Создайте виртуальное окружение
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
# или
.venv\Scripts\activate     # Windows

# Установите зависимости
pip install -r tests/requirements.txt

# Убедитесь что backend запущен (через docker-compose или локально)
# Установите переменную окружения
export API_BASE_URL=http://localhost:8000  # Linux/Mac
# или
set API_BASE_URL=http://localhost:8000     # Windows

# Запустите тесты
pytest -v

# С подробным выводом
pytest -v -s

# С HTML отчётом
pytest -v --html=report.html --self-contained-html
```

## Разработка и дебаг

### Локальный запуск Backend для разработки

```bash
# Запустите только PostgreSQL
docker-compose up postgres

# В другом терминале запустите backend локально
cd backend
pip install -r requirements.txt

# Установите переменную для БД
export DATABASE_URL=postgresql://testuser:testpass@localhost:5432/testdb

# Запустите с hot-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Теперь вы можете редактировать код и видеть изменения мгновенно.

### Дебаг падающих тестов

```bash
# Запустите тесты с подробным traceback
docker-compose run tests pytest -v --tb=long

# Остановка на первом падении
docker-compose run tests pytest -v -x

# Запуск только упавших тестов (из прошлого запуска)
docker-compose run tests pytest -v --lf

# Интерактивный дебаггер (pdb) при падении
docker-compose run tests pytest -v --pdb
```

### Проверка покрытия кода тестами

```bash
# Запуск тестов с покрытием
docker-compose run tests pytest --cov=. --cov-report=html

# Затем откройте htmlcov/index.html в браузере
```

## Работа с Kubernetes

### Предварительная подготовка

```bash
# Соберите Docker образы
docker build -t users-api-backend:latest -f docker/backend.Dockerfile .
docker build -t users-api-tests:latest -f docker/tests.Dockerfile .

# Для Minikube загрузите образы в кластер
minikube image load users-api-backend:latest
minikube image load users-api-tests:latest

# Для Kind загрузите образы
kind load docker-image users-api-backend:latest
kind load docker-image users-api-tests:latest
```

### Развёртывание в Kubernetes

```bash
# Создайте namespace
kubectl apply -f k8s/namespace.yaml

# Разверните PostgreSQL
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml

# Разверните Backend API
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

# Проверьте статус подов
kubectl get pods -n users-api

# Дождитесь пока все поды будут Ready
kubectl wait --for=condition=ready pod -l app=backend -n users-api --timeout=120s
```

### Запуск тестов в Kubernetes

```bash
# Запустите Job с тестами
kubectl apply -f k8s/tests-job.yaml

# Проверьте статус Job
kubectl get jobs -n users-api

# Найдите имя пода с тестами
kubectl get pods -n users-api | grep api-tests

# Посмотрите логи выполнения тестов
kubectl logs -n users-api <pod-name>

# Следите за логами в реальном времени
kubectl logs -n users-api <pod-name> -f

# Проверьте статус завершения
kubectl get job api-tests -n users-api -o jsonpath='{.status.succeeded}'
```

### Port-forward для доступа к API из локальной машины

```bash
# Пробросьте порт backend service
kubectl port-forward -n users-api svc/backend 8000:8000

# Теперь API доступно на http://localhost:8000
# Откройте http://localhost:8000/docs в браузере
```

### Запуск тестов локально против K8s

```bash
# В одном терминале сделайте port-forward
kubectl port-forward -n users-api svc/backend 8000:8000

# В другом терминале запустите тесты
export API_BASE_URL=http://localhost:8000
pytest -v
```

### Удаление ресурсов из Kubernetes

```bash
# Удалить Job с тестами
kubectl delete job api-tests -n users-api

# Удалить все ресурсы проекта
kubectl delete namespace users-api
```

## Полезные команды

### Docker

```bash
# Очистка неиспользуемых ресурсов Docker
docker system prune -a

# Просмотр использования ресурсов контейнерами
docker stats

# Удаление всех остановленных контейнеров
docker container prune

# Удаление неиспользуемых образов
docker image prune -a
```

### Kubernetes

```bash
# Получить все ресурсы в namespace
kubectl get all -n users-api

# Описание ресурса (для дебага)
kubectl describe pod <pod-name> -n users-api

# Посмотреть события в namespace
kubectl get events -n users-api --sort-by='.lastTimestamp'

# Выполнить команду в поде
kubectl exec -it <pod-name> -n users-api -- sh

# Скопировать файл из пода
kubectl cp users-api/<pod-name>:/path/to/file ./local-file

# Масштабирование deployment
kubectl scale deployment backend --replicas=3 -n users-api
```

## API Endpoints

| Метод  | Endpoint          | Описание                     |
|--------|-------------------|------------------------------|
| GET    | /                 | Health check                 |
| POST   | /users            | Создать пользователя         |
| GET    | /users            | Список всех пользователей    |
| GET    | /users/{user_id}  | Получить пользователя по ID  |
| PUT    | /users/{user_id}  | Обновить пользователя        |
| DELETE | /users/{user_id}  | Удалить пользователя         |
| GET    | /docs             | Swagger UI                   |
| GET    | /redoc            | ReDoc                        |

### Примеры использования API

```bash
# Health check
curl http://localhost:8000/

# Создать пользователя
curl -X POST http://localhost:8000/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "full_name": "Test User"
  }'

# Получить список пользователей
curl http://localhost:8000/users

# Получить пользователя по ID
curl http://localhost:8000/users/1

# Обновить пользователя
curl -X PUT http://localhost:8000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"full_name": "Updated Name"}'

# Удалить пользователя
curl -X DELETE http://localhost:8000/users/1
```

## Архитектура тестов

### Организация тестов

- **test_users_crud.py** - Позитивные CRUD тесты
- **test_users_negative.py** - Негативные сценарии (ошибки, валидация)
- **test_users_edge_cases.py** - Граничные случаи и специальные сценарии

### Ключевые фикстуры (conftest.py)

- `base_url` - Базовый URL API
- `api_client` - HTTP клиент с автоматическим логированием
- `created_user` - Автоматическое создание/удаление тестового пользователя
- `multiple_users` - Создание нескольких пользователей для тестов пагинации

### Вспомогательные функции

- `utils/logger.py` - Логирование HTTP запросов/ответов
- `utils/helpers.py` - Генераторы тестовых данных, ассерты

### Параметризация

Тесты используют `@pytest.mark.parametrize` для проверки множества сценариев:

```python
@pytest.mark.parametrize("skip,limit,expected_count", [
    (0, 2, 2),
    (2, 2, 2),
    (0, 100, 5),
])
def test_pagination(api_client, multiple_users, skip, limit, expected_count):
    # Один тест проверяет разные комбинации параметров
```

## Troubleshooting

### Backend не запускается

```bash
# Проверьте логи
docker-compose logs backend

# Частая причина - БД не готова
# Убедитесь что PostgreSQL запущена и прошла health check
docker-compose ps

# Пересоздайте контейнеры
docker-compose down -v
docker-compose up --build
```

### Тесты падают с ошибкой подключения

```bash
# Убедитесь что backend запущен и доступен
curl http://localhost:8000/

# Проверьте переменную окружения API_BASE_URL
docker-compose run tests env | grep API_BASE_URL

# В docker-compose.yml должно быть: API_BASE_URL=http://backend:8000
```

### PostgreSQL ошибки подключения

```bash
# Проверьте что PostgreSQL запущена
docker-compose ps postgres

# Проверьте health check
docker-compose logs postgres | grep "database system is ready"

# Пересоздайте БД
docker-compose down -v  # Удалит данные БД!
docker-compose up postgres
```

### Kubernetes поды не стартуют

```bash
# Проверьте описание пода
kubectl describe pod <pod-name> -n users-api

# Частые причины:
# - Образ не найден (не загружен в кластер)
# - Недостаточно ресурсов
# - Ошибка в переменных окружения

# Для Minikube/Kind загрузите образы:
minikube image load users-api-backend:latest
minikube image load users-api-tests:latest
```

## Дальнейшее развитие проекта

Идеи для расширения учебного проекта:

1. **CI/CD**
   - Добавить GitHub Actions / GitLab CI
   - Автоматический запуск тестов при push

2. **Отчёты**
   - Allure Framework для красивых отчётов
   - Интеграция с TestRail / Zephyr

3. **Безопасность**
   - JWT аутентификация
   - Role-based access control (RBAC)

4. **Мониторинг**
   - Prometheus метрики
   - Grafana дашборды
   - Distributed tracing (Jaeger)

5. **Дополнительные тесты**
   - Performance тесты (Locust)
   - Contract тесты (Pact)
   - Security тесты (OWASP ZAP)

## Образовательные цели

Этот проект помогает освоить:

- Написание автотестов на pytest
- Работу с REST API
- Фикстуры, параметризацию, маркеры
- Docker и Docker Compose
- Kubernetes основы
- CI/CD практики
- Best practices автоматизации тестирования

## Лицензия

Учебный проект. Свободное использование.

## Контакты

Если есть вопросы по проекту - создайте Issue в репозитории.

---

**Удачного обучения автоматизации тестирования!**
