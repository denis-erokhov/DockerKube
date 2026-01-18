"""
Позитивные тесты CRUD операций для Users API.
Проверяют стандартные сценарии использования.
"""
import pytest
import requests
from utils.helpers import create_test_user_data, assert_user_fields, assert_response_has_fields


class TestCreateUser:
    """Тесты создания пользователя (CREATE)."""

    def test_create_user_success(self, api_client: requests.Session):
        """Успешное создание пользователя со всеми полями."""
        user_data = create_test_user_data(
            full_name="John Doe"
        )

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201, "Should return 201 Created"
        user = response.json()

        # Проверяем наличие обязательных полей в ответе
        assert_response_has_fields(user, ["id", "email", "username", "created_at"])

        # Проверяем что возвращённые данные совпадают с отправленными
        assert_user_fields(user, user_data)

        # Проверяем что ID был присвоен
        assert user["id"] > 0, "User should have a positive ID"

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    def test_create_user_minimal_fields(self, api_client: requests.Session):
        """Создание пользователя только с обязательными полями."""
        user_data = {
            "email": "minimal@example.com",
            "username": "minimaluser"
        }

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201
        user = response.json()
        assert user["email"] == user_data["email"]
        assert user["username"] == user_data["username"]
        assert user["is_active"] is True, "is_active should default to True"

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    def test_create_inactive_user(self, api_client: requests.Session):
        """Создание неактивного пользователя."""
        user_data = create_test_user_data(is_active=False)

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201
        user = response.json()
        assert user["is_active"] is False

        # Cleanup
        api_client.delete(f"/users/{user['id']}")


class TestReadUser:
    """Тесты получения пользователя (READ)."""

    def test_get_user_by_id(self, created_user):
        """Получение существующего пользователя по ID."""
        # created_user фикстура автоматически создаёт и удаляет пользователя
        user_id = created_user["id"]

        # В фикстуре мы уже используем api_client, но здесь нужен доступ к нему
        # Поэтому используем прямой запрос или получаем api_client через параметр
        import requests
        import os
        base_url = os.getenv("API_BASE_URL", "http://localhost:8000")

        response = requests.get(f"{base_url}/users/{user_id}")

        assert response.status_code == 200
        user = response.json()
        assert user["id"] == created_user["id"]
        assert user["email"] == created_user["email"]

    def test_get_users_list(self, api_client: requests.Session, multiple_users):
        """Получение списка всех пользователей."""
        response = api_client.get("/users")

        assert response.status_code == 200
        users = response.json()
        assert isinstance(users, list)
        assert len(users) >= 5, "Should contain at least the 5 created users"

    @pytest.mark.parametrize("skip,limit,expected_count", [
        (0, 2, 2),    # Первые 2 пользователя
        (2, 2, 2),    # Следующие 2 пользователя
        (0, 100, 5),  # Все пользователи (не больше 5)
    ])
    def test_get_users_pagination(
        self,
        api_client: requests.Session,
        multiple_users,
        skip: int,
        limit: int,
        expected_count: int
    ):
        """Тестирование пагинации списка пользователей."""
        response = api_client.get("/users", params={"skip": skip, "limit": limit})

        assert response.status_code == 200
        users = response.json()
        assert len(users) <= expected_count


class TestUpdateUser:
    """Тесты обновления пользователя (UPDATE)."""

    def test_update_user_full_name(self, api_client: requests.Session, created_user):
        """Обновление полного имени пользователя."""
        user_id = created_user["id"]
        update_data = {"full_name": "Updated Name"}

        response = api_client.put(f"/users/{user_id}", json=update_data)

        assert response.status_code == 200
        updated_user = response.json()
        assert updated_user["full_name"] == "Updated Name"
        # Остальные поля не должны измениться
        assert updated_user["email"] == created_user["email"]
        assert updated_user["username"] == created_user["username"]

    def test_update_user_email(self, api_client: requests.Session, created_user):
        """Обновление email пользователя."""
        user_id = created_user["id"]
        new_email = "newemail@example.com"
        update_data = {"email": new_email}

        response = api_client.put(f"/users/{user_id}", json=update_data)

        assert response.status_code == 200
        updated_user = response.json()
        assert updated_user["email"] == new_email

    def test_update_user_multiple_fields(self, api_client: requests.Session, created_user):
        """Обновление нескольких полей одновременно."""
        user_id = created_user["id"]
        update_data = {
            "full_name": "New Full Name",
            "is_active": False
        }

        response = api_client.put(f"/users/{user_id}", json=update_data)

        assert response.status_code == 200
        updated_user = response.json()
        assert updated_user["full_name"] == update_data["full_name"]
        assert updated_user["is_active"] == update_data["is_active"]

    def test_deactivate_user(self, api_client: requests.Session, created_user):
        """Деактивация пользователя."""
        user_id = created_user["id"]

        response = api_client.put(f"/users/{user_id}", json={"is_active": False})

        assert response.status_code == 200
        assert response.json()["is_active"] is False


class TestDeleteUser:
    """Тесты удаления пользователя (DELETE)."""

    def test_delete_user_success(self, api_client: requests.Session):
        """Успешное удаление пользователя."""
        # Создаём пользователя
        user_data = create_test_user_data()
        create_response = api_client.post("/users", json=user_data)
        user_id = create_response.json()["id"]

        # Удаляем пользователя
        delete_response = api_client.delete(f"/users/{user_id}")
        assert delete_response.status_code == 204, "Should return 204 No Content"

        # Проверяем что пользователь действительно удалён
        get_response = api_client.get(f"/users/{user_id}")
        assert get_response.status_code == 404, "User should not exist after deletion"

    def test_delete_user_idempotency(self, api_client: requests.Session, created_user):
        """Проверка что повторное удаление возвращает 404."""
        user_id = created_user["id"]

        # Первое удаление
        response1 = api_client.delete(f"/users/{user_id}")
        assert response1.status_code == 204

        # Повторное удаление того же пользователя
        response2 = api_client.delete(f"/users/{user_id}")
        assert response2.status_code == 404, "Second delete should return 404"
