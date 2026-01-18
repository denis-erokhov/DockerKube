"""
SQLAlchemy модели для базы данных.
Определяют структуру таблиц и отношения между ними.
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from .database import Base


class User(Base):
    """
    Модель пользователя в системе.

    Поля:
        id: Уникальный идентификатор (автоинкремент)
        email: Email пользователя (уникальный)
        username: Имя пользователя (уникальный)
        full_name: Полное имя
        is_active: Флаг активности пользователя
        created_at: Время создания записи
        updated_at: Время последнего обновления
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', email='{self.email}')>"
