# Используем официальный образ Python 3.11 slim
FROM python:3.11-slim

# Устанавливаем рабочую директорию
WORKDIR /tests

# Копируем файл с зависимостями для тестов
COPY tests/requirements.txt .

# Устанавливаем зависимости для тестов
RUN pip install --no-cache-dir -r requirements.txt

# Копируем код автотестов
COPY tests/ .

# Устанавливаем переменную окружения для pytest
# Отключаем создание __pycache__ директорий
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# По умолчанию запускаем все тесты с verbose выводом
# Эта команда может быть переопределена при запуске контейнера
CMD ["pytest", "-v", "--tb=short"]
