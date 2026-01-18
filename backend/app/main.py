"""
Главный файл FastAPI приложения.
Определяет все API эндпоинты и настройки приложения.
"""
from typing import List
from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from . import crud, models, schemas
from .database import engine, get_db

# Создаём таблицы в БД при старте приложения
models.Base.metadata.create_all(bind=engine)

# Инициализируем FastAPI приложение
app = FastAPI(
    title="User Management API",
    description="RESTful API для управления пользователями (учебный проект для автотестов)",
    version="1.0.0",
    docs_url="/docs",  # Swagger UI
    redoc_url="/redoc"  # ReDoc
)


@app.get("/", tags=["Health"])
def health_check():
    """
    Health check эндпоинт для проверки работоспособности API.
    Используется в Docker health checks и мониторинге.
    """
    return {
        "status": "ok",
        "service": "User Management API",
        "version": "1.0.0"
    }


@app.post(
    "/users",
    response_model=schemas.UserResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Users"],
    summary="Создать нового пользователя"
)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    """
    Создать нового пользователя в системе.

    - **email**: Должен быть уникальным и валидным email адресом
    - **username**: Должен быть уникальным (3-50 символов)
    - **full_name**: Опционально, полное имя пользователя
    - **is_active**: По умолчанию True

    Возвращает созданного пользователя с присвоенным ID и timestamp'ами.
    """
    # Проверяем существование email
    if crud.get_user_by_email(db, user.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Email '{user.email}' already registered"
        )

    # Проверяем существование username
    if crud.get_user_by_username(db, user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Username '{user.username}' already taken"
        )

    try:
        return crud.create_user(db=db, user=user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email or username already exists"
        )


@app.get(
    "/users",
    response_model=List[schemas.UserResponse],
    tags=["Users"],
    summary="Получить список пользователей"
)
def read_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """
    Получить список всех пользователей с пагинацией.

    - **skip**: Количество записей для пропуска (offset), по умолчанию 0
    - **limit**: Максимальное количество записей в ответе, по умолчанию 100

    Возвращает список пользователей.
    """
    if skip < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Parameter 'skip' must be >= 0"
        )

    if limit < 1 or limit > 1000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Parameter 'limit' must be between 1 and 1000"
        )

    users = crud.get_users(db, skip=skip, limit=limit)
    return users


@app.get(
    "/users/{user_id}",
    response_model=schemas.UserResponse,
    tags=["Users"],
    summary="Получить пользователя по ID"
)
def read_user(user_id: int, db: Session = Depends(get_db)):
    """
    Получить информацию о конкретном пользователе по его ID.

    - **user_id**: ID пользователя (целое положительное число)

    Возвращает данные пользователя или 404 если не найден.
    """
    if user_id < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User ID must be a positive integer"
        )

    db_user = crud.get_user(db, user_id=user_id)
    if db_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found"
        )
    return db_user


@app.put(
    "/users/{user_id}",
    response_model=schemas.UserResponse,
    tags=["Users"],
    summary="Обновить пользователя"
)
def update_user(user_id: int, user: schemas.UserUpdate, db: Session = Depends(get_db)):
    """
    Обновить данные существующего пользователя.
    Можно обновить только некоторые поля, остальные останутся без изменений.

    - **user_id**: ID пользователя для обновления
    - Все поля в теле запроса опциональны

    Возвращает обновлённого пользователя или 404 если не найден.
    """
    if user_id < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User ID must be a positive integer"
        )

    # Проверяем что хотя бы одно поле передано для обновления
    # Используем len() вместо any() т.к. any([False]) = False
    if not user.model_dump(exclude_unset=True):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one field must be provided for update"
        )

    # Если обновляется email, проверяем уникальность
    if user.email:
        existing_user = crud.get_user_by_email(db, user.email)
        if existing_user and existing_user.id != user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Email '{user.email}' already registered"
            )

    # Если обновляется username, проверяем уникальность
    if user.username:
        existing_user = crud.get_user_by_username(db, user.username)
        if existing_user and existing_user.id != user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Username '{user.username}' already taken"
            )

    try:
        db_user = crud.update_user(db, user_id=user_id, user_update=user)
        if db_user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User with ID {user_id} not found"
            )
        return db_user
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email or username already exists"
        )


@app.delete(
    "/users/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["Users"],
    summary="Удалить пользователя"
)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    """
    Удалить пользователя из системы.

    - **user_id**: ID пользователя для удаления

    Возвращает 204 No Content при успешном удалении или 404 если пользователь не найден.
    """
    if user_id < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User ID must be a positive integer"
        )

    success = crud.delete_user(db, user_id=user_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found"
        )
    return None
