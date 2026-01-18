"""CRUD операции (Create, Read, Update, Delete) для работы с базой данных.
Изолируют бизнес-логику от слоя API.
"""
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from . import models, schemas


def get_user(db: Session, user_id: int) -> Optional[models.User]:
    """Получить пользователя по ID.

    Args:
        db: Сессия БД
        user_id: ID пользователя
    """
    return db.query(models.User).filter(models.User.id == user_id).first()


def get_user_by_email(db: Session, email: str) -> Optional[models.User]:
    """Получить пользователя по email."""
    return db.query(models.User).filter(models.User.email == email).first()


def get_user_by_username(db: Session, username: str) -> Optional[models.User]:
    """Получить пользователя по username."""
    return db.query(models.User).filter(models.User.username == username).first()


def get_users(db: Session, skip: int = 0, limit: int = 100) -> List[models.User]:
    """Получить список пользователей с пагинацией.

    Args:
        db: Сессия БД
        skip: Сколько записей пропустить (offset)
        limit: Максимальное количество записей
    """
    return db.query(models.User).offset(skip).limit(limit).all()


def create_user(db: Session, user: schemas.UserCreate) -> models.User:
    """Создать нового пользователя.

    Args:
        db: Сессия БД
        user: Данные для создания пользователя

    Returns:
        Созданный объект User

    Raises:
        IntegrityError: Если email или username уже существуют
    """
    db_user = models.User(
        email=user.email,
        username=user.username,
        full_name=user.full_name,
        is_active=user.is_active
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def update_user(db: Session, user_id: int, user_update: schemas.UserUpdate) -> Optional[models.User]:
    """
    Обновить существующего пользователя.
    Обновляет только те поля, которые переданы (не None).

    Args:
        db: Сессия БД
        user_id: ID пользователя
        user_update: Данные для обновления

    Returns:
        Обновлённый объект User или None если пользователь не найден
    """
    db_user = get_user(db, user_id)
    if not db_user:
        return None

    # Обновляем только переданные поля
    update_data = user_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_user, field, value)

    db.commit()
    db.refresh(db_user)
    return db_user


def delete_user(db: Session, user_id: int) -> bool:
    """
    Удалить пользователя.

    Args:
        db: Сессия БД
        user_id: ID пользователя

    Returns:
        True если пользователь был удалён, False если не найден
    """
    db_user = get_user(db, user_id)
    if not db_user:
        return False

    db.delete(db_user)
    db.commit()
    return True
