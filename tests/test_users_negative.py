"""
Негативные тесты Users API.
Проверяют обработку ошибок и валидацию данных.
"""
import pytest
import requests
from utils.helpers import create_test_user_data


class TestCreateUserNegative:
    """Негативные тесты создания пользователя."""

    def test_create_user_duplicate_email(self, api_client: requests.Session, created_user):
        """Попытка создать пользователя с уже существующим email."""
        duplicate_data = create_test_user_data(
            email=created_user["email"]  # Используем email существующего пользователя
        )

        response = api_client.post("/users", json=duplicate_data)

        assert response.status_code == 400, "Should return 400 Bad Request"
        error = response.json()
        assert "detail" in error
        assert "email" in error["detail"].lower(), "Error message should mention email"

    def test_create_user_duplicate_username(self, api_client: requests.Session, created_user):
        """Попытка создать пользователя с уже существующим username."""
        duplicate_data = create_test_user_data(
            username=created_user["username"]
        )

        response = api_client.post("/users", json=duplicate_data)

        assert response.status_code == 400
        error = response.json()
        assert "username" in error["detail"].lower()

    def test_create_user_invalid_email(self, api_client: requests.Session):
        """Попытка создать пользователя с невалидным email."""
        user_data = create_test_user_data(
            email="not-an-email"  # Невалидный формат email
        )

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 422, "Should return 422 Unprocessable Entity for validation error"

    def test_create_user_missing_email(self, api_client: requests.Session):
        """Попытка создать пользователя без обязательного поля email."""
        user_data = {
            "username": "testuser"
            # email отсутствует
        }

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 422, "Should return 422 for missing required field"

    def test_create_user_missing_username(self, api_client: requests.Session):
        """Попытка создать пользователя без обязательного поля username."""
        user_data = {
            "email": "test@example.com"
            # username отсутствует
        }

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 422

    @pytest.mark.parametrize("username", [
        "ab",           # Слишком короткий (< 3 символов)
        "a" * 51,       # Слишком длинный (> 50 символов)
    ])
    def test_create_user_invalid_username_length(self, api_client: requests.Session, username: str):
        """Тестирование валидации длины username."""
        user_data = create_test_user_data(username=username)

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 422, f"Username '{username}' should be rejected"

    def test_create_user_empty_body(self, api_client: requests.Session):
        """Попытка создать пользователя с пустым телом запроса."""
        response = api_client.post("/users", json={})

        assert response.status_code == 422


class TestReadUserNegative:
    """Негативные тесты получения пользователя."""

    def test_get_nonexistent_user(self, api_client: requests.Session):
        """Попытка получить несуществующего пользователя."""
        non_existent_id = 999999

        response = api_client.get(f"/users/{non_existent_id}")

        assert response.status_code == 404, "Should return 404 Not Found"
        error = response.json()
        assert "detail" in error

    @pytest.mark.parametrize("invalid_id", [
        0,      # ID должен быть > 0
        -1,     # Отрицательный ID
        -100,   # Большой отрицательный ID
    ])
    def test_get_user_invalid_id(self, api_client: requests.Session, invalid_id: int):
        """Попытка получить пользователя с невалидным ID."""
        response = api_client.get(f"/users/{invalid_id}")

        assert response.status_code == 400, f"Invalid ID {invalid_id} should return 400"

    def test_get_user_invalid_id_type(self, api_client: requests.Session):
        """Попытка получить пользователя с ID неправильного типа."""
        response = api_client.get("/users/not-a-number")

        assert response.status_code == 422, "Non-integer ID should return 422"

    @pytest.mark.parametrize("skip,limit", [
        (-1, 10),     # Отрицательный skip
        (0, 0),       # limit = 0
        (0, -5),      # Отрицательный limit
        (0, 1001),    # limit > максимального значения (1000)
    ])
    def test_get_users_invalid_pagination(
        self,
        api_client: requests.Session,
        skip: int,
        limit: int
    ):
        """Тестирование валидации параметров пагинации."""
        response = api_client.get("/users", params={"skip": skip, "limit": limit})

        assert response.status_code == 400, \
            f"Invalid pagination (skip={skip}, limit={limit}) should return 400"


class TestUpdateUserNegative:
    """Негативные тесты обновления пользователя."""

    def test_update_nonexistent_user(self, api_client: requests.Session):
        """Попытка обновить несуществующего пользователя."""
        update_data = {"full_name": "New Name"}

        response = api_client.put("/users/999999", json=update_data)

        assert response.status_code == 404

    def test_update_user_empty_body(self, api_client: requests.Session, created_user):
        """Попытка обновить пользователя с пустым телом запроса."""
        user_id = created_user["id"]

        response = api_client.put(f"/users/{user_id}", json={})

        assert response.status_code == 400, "Empty update should return 400"

    def test_update_user_duplicate_email(
        self,
        api_client: requests.Session,
        multiple_users
    ):
        """Попытка обновить email на уже существующий."""
        user1 = multiple_users[0]
        user2 = multiple_users[1]

        # Пытаемся обновить email user1 на email user2
        response = api_client.put(
            f"/users/{user1['id']}",
            json={"email": user2["email"]}
        )

        assert response.status_code == 400
        error = response.json()
        assert "email" in error["detail"].lower()

    def test_update_user_duplicate_username(
        self,
        api_client: requests.Session,
        multiple_users
    ):
        """Попытка обновить username на уже существующий."""
        user1 = multiple_users[0]
        user2 = multiple_users[1]

        response = api_client.put(
            f"/users/{user1['id']}",
            json={"username": user2["username"]}
        )

        assert response.status_code == 400
        error = response.json()
        assert "username" in error["detail"].lower()

    def test_update_user_invalid_email(self, api_client: requests.Session, created_user):
        """Попытка обновить email на невалидный."""
        user_id = created_user["id"]

        response = api_client.put(
            f"/users/{user_id}",
            json={"email": "invalid-email"}
        )

        assert response.status_code == 422


class TestDeleteUserNegative:
    """Негативные тесты удаления пользователя."""

    def test_delete_nonexistent_user(self, api_client: requests.Session):
        """Попытка удалить несуществующего пользователя."""
        response = api_client.delete("/users/999999")

        assert response.status_code == 404

    @pytest.mark.parametrize("invalid_id", [0, -1, -100])
    def test_delete_user_invalid_id(self, api_client: requests.Session, invalid_id: int):
        """Попытка удалить пользователя с невалидным ID."""
        response = api_client.delete(f"/users/{invalid_id}")

        assert response.status_code == 400
