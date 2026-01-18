"""
Вспомогательные функции для тестов.
"""
import random
import string
from typing import Dict, Any


def generate_random_email() -> str:
    """
    Генерирует случайный email для тестов.

    Returns:
        Уникальный email адрес
    """
    random_string = ''.join(random.choices(string.ascii_lowercase + string.digits, k=10))
    return f"test_{random_string}@example.com"


def generate_random_username(prefix: str = "user") -> str:
    """
    Генерирует случайное имя пользователя.

    Args:
        prefix: Префикс для username

    Returns:
        Уникальное имя пользователя
    """
    random_string = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    return f"{prefix}_{random_string}"


def create_test_user_data(**overrides) -> Dict[str, Any]:
    """
    Создаёт словарь с данными тестового пользователя.
    Автоматически генерирует уникальные email и username.

    Args:
        **overrides: Переопределение любых полей

    Returns:
        Словарь с данными пользователя

    Example:
        >>> user_data = create_test_user_data(full_name="John Doe")
        >>> user_data
        {
            'email': 'test_abc123@example.com',
            'username': 'user_xyz789',
            'full_name': 'John Doe',
            'is_active': True
        }
    """
    default_data = {
        "email": generate_random_email(),
        "username": generate_random_username(),
        "full_name": "Test User",
        "is_active": True
    }

    default_data.update(overrides)
    return default_data


def assert_user_fields(user_response: Dict[str, Any], expected_data: Dict[str, Any]) -> None:
    """
    Проверяет что поля пользователя в ответе совпадают с ожидаемыми.

    Args:
        user_response: Ответ API с данными пользователя
        expected_data: Ожидаемые данные

    Raises:
        AssertionError: Если данные не совпадают
    """
    for key, expected_value in expected_data.items():
        actual_value = user_response.get(key)
        assert actual_value == expected_value, \
            f"Field '{key}': expected '{expected_value}', got '{actual_value}'"


def assert_response_has_fields(response_json: Dict[str, Any], required_fields: list) -> None:
    """
    Проверяет наличие обязательных полей в ответе API.

    Args:
        response_json: JSON ответ от API
        required_fields: Список обязательных полей

    Raises:
        AssertionError: Если какое-то поле отсутствует
    """
    missing_fields = [field for field in required_fields if field not in response_json]
    assert not missing_fields, f"Missing required fields: {missing_fields}"
