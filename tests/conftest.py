"""
Конфигурация pytest и общие фикстуры для всех тестов.
Фикстуры автоматически доступны во всех тестовых файлах.
"""
import os
import pytest
import requests
from typing import Generator
from utils.logger import log_request, log_response


# Получаем базовый URL API из переменной окружения
API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")


@pytest.fixture(scope="session")
def base_url() -> str:
    """
    Фикстура для базового URL API.
    Scope='session' означает что создаётся один раз на всю сессию тестов.

    Returns:
        Базовый URL API
    """
    return API_BASE_URL


@pytest.fixture(scope="session")
def api_client(base_url: str) -> Generator[requests.Session, None, None]:
    """
    Фикстура для HTTP клиента с автоматическим логированием запросов.
    Session позволяет переиспользовать TCP соединения для ускорения тестов.

    Args:
        base_url: Базовый URL API (из фикстуры)

    Yields:
        Настроенный requests.Session клиент
    """
    session = requests.Session()
    session.headers.update({"Content-Type": "application/json"})

    # Сохраняем оригинальный метод request
    original_request = session.request

    # Оборачиваем request для автоматического логирования
    def logged_request(method, url, **kwargs):
        full_url = url if url.startswith('http') else f"{base_url}{url}"
        log_request(method, full_url, **kwargs)
        response = original_request(method, full_url, **kwargs)
        log_response(response)
        return response

    session.request = logged_request

    yield session

    session.close()


@pytest.fixture
def created_user(api_client: requests.Session):
    """
    Фикстура для создания тестового пользователя.
    Автоматически удаляет пользователя после теста (cleanup).

    Args:
        api_client: HTTP клиент (из фикстуры)

    Yields:
        Созданный пользователь (dict с данными из API)

    Example:
        def test_update_user(created_user):
            user_id = created_user['id']
            # тест обновления пользователя
    """
    from utils.helpers import create_test_user_data

    # Setup: создаём пользователя
    user_data = create_test_user_data()
    response = api_client.post("/users", json=user_data)
    assert response.status_code == 201, f"Failed to create test user: {response.text}"
    user = response.json()

    yield user

    # Teardown: удаляем пользователя после теста
    api_client.delete(f"/users/{user['id']}")


@pytest.fixture
def multiple_users(api_client: requests.Session):
    """
    Фикстура для создания нескольких тестовых пользователей.
    Полезна для тестирования пагинации и фильтрации.

    Args:
        api_client: HTTP клиент

    Yields:
        Список созданных пользователей

    Example:
        def test_list_users(multiple_users):
            assert len(multiple_users) == 5
    """
    from utils.helpers import create_test_user_data

    created_users = []

    # Создаём 5 пользователей
    for i in range(5):
        user_data = create_test_user_data(
            full_name=f"Test User {i+1}"
        )
        response = api_client.post("/users", json=user_data)
        assert response.status_code == 201
        created_users.append(response.json())

    yield created_users

    # Cleanup: удаляем всех созданных пользователей
    for user in created_users:
        api_client.delete(f"/users/{user['id']}")


@pytest.fixture(autouse=True)
def wait_for_api(base_url: str):
    """
    Автоматическая фикстура (autouse=True) для проверки доступности API.
    Выполняется перед каждым тестом.

    Args:
        base_url: Базовый URL API

    Raises:
        Exception: Если API недоступно
    """
    import time
    max_retries = 30
    retry_delay = 1

    for attempt in range(max_retries):
        try:
            response = requests.get(f"{base_url}/", timeout=2)
            if response.status_code == 200:
                return
        except requests.exceptions.RequestException:
            pass

        if attempt < max_retries - 1:
            time.sleep(retry_delay)

    raise Exception(f"API at {base_url} is not available after {max_retries} attempts")
