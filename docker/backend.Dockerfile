FROM python:3.11-slim
# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /app
COPY backend/requirements.txt .
# Устанавливаем зависимости
# --no-cache-dir экономит место, не сохраняя кеш pip
RUN pip install --no-cache-dir -r requirements.txt

# Копируем весь код приложения
COPY backend/app ./app

# Открываем порт 8000 для FastAPI
EXPOSE 8000

# Команда запуска приложения
# --host 0.0.0.0 позволяет принимать соединения извне контейнера
# --reload автоматически перезагружает приложение при изменении кода (для dev режима)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
