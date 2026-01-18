"""
Конфигурация подключения к базе данных PostgreSQL.
Используем SQLAlchemy для ORM и управления сессиями.
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Получаем DATABASE_URL из переменных окружения
# Формат: postgresql://user:password@host:port/database
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://testuser:testpass@postgres:5432/testdb"
)

# Создаём engine для подключения к БД
# echo=True выводит SQL запросы в консоль (полезно для отладки)
engine = create_engine(DATABASE_URL, echo=False)

# Фабрика для создания сессий БД
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Базовый класс для всех моделей БД
Base = declarative_base()


def get_db():
    """
    Dependency для получения сессии БД в FastAPI эндпоинтах.
    Автоматически закрывает сессию после использования.

    Использование:
        @app.get("/users")
        def get_users(db: Session = Depends(get_db)):
            ...
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
