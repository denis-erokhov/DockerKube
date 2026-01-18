"""
Pydantic схемы для валидации входящих и исходящих данных.
Обеспечивают type safety и автоматическую валидацию.
"""
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    """Базовая схема с общими полями для пользователя."""
    email: EmailStr = Field(..., description="Email адрес пользователя")
    username: str = Field(..., min_length=3, max_length=50, description="Уникальное имя пользователя")
    full_name: Optional[str] = Field(None, max_length=100, description="Полное имя пользователя")
    is_active: bool = Field(True, description="Активен ли пользователь")


class UserCreate(UserBase):
    """
    Схема для создания нового пользователя.
    Наследует все поля от UserBase.
    """
    pass


class UserUpdate(BaseModel):
    """
    Схема для обновления существующего пользователя.
    Все поля опциональны - можно обновить только некоторые.
    """
    email: Optional[EmailStr] = None
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    full_name: Optional[str] = Field(None, max_length=100)
    is_active: Optional[bool] = None


class UserResponse(UserBase):
    """
    Схема для ответа API с данными пользователя.
    Включает дополнительные поля из БД (id, timestamps).
    """
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        """Позволяет Pydantic работать с SQLAlchemy моделями."""
        from_attributes = True


class ErrorResponse(BaseModel):
    """Стандартная схема для ошибок API."""
    detail: str = Field(..., description="Описание ошибки")
