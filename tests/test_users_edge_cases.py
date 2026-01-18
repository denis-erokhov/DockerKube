"""
Тесты граничных случаев (edge cases) для Users API.
Проверяют поведение на границах валидации и необычные сценарии.
"""
import pytest
import requests
from utils.helpers import create_test_user_data


class TestEdgeCases:
    """Тесты граничных случаев."""

    def test_create_user_username_min_length(self, api_client: requests.Session):
        """Создание пользователя с минимально допустимой длиной username (3 символа)."""
        user_data = create_test_user_data(username="abc")

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201, "Username of 3 chars should be accepted"
        user = response.json()
        assert user["username"] == "abc"

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    def test_create_user_username_max_length(self, api_client: requests.Session):
        """Создание пользователя с максимально допустимой длиной username (50 символов)."""
        max_username = "a" * 50
        user_data = create_test_user_data(username=max_username)

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201, "Username of 50 chars should be accepted"
        user = response.json()
        assert len(user["username"]) == 50

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    def test_create_user_fullname_max_length(self, api_client: requests.Session):
        """Создание пользователя с максимально допустимой длиной full_name (100 символов)."""
        max_fullname = "A" * 100
        user_data = create_test_user_data(full_name=max_fullname)

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201
        user = response.json()
        assert len(user["full_name"]) == 100

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    def test_create_user_fullname_exceeds_max(self, api_client: requests.Session):
        """Попытка создать пользователя с full_name > 100 символов."""
        too_long_fullname = "A" * 101
        user_data = create_test_user_data(full_name=too_long_fullname)

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 422, "Too long full_name should be rejected"

    def test_create_user_null_fullname(self, api_client: requests.Session):
        """Создание пользователя с full_name = null (опциональное поле)."""
        user_data = create_test_user_data()
        user_data["full_name"] = None

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201
        user = response.json()
        assert user["full_name"] is None

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    def test_create_user_special_chars_in_username(self, api_client: requests.Session):
        """Создание пользователя с спецсимволами в username."""
        special_username = "user_123-test"
        user_data = create_test_user_data(username=special_username)

        response = api_client.post("/users", json=user_data)

        # Зависит от бизнес-правил: принимается или нет
        # В нашем случае FastAPI/Pydantic примет любую строку
        assert response.status_code == 201
        user = response.json()
        assert user["username"] == special_username

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    def test_create_user_unicode_in_fullname(self, api_client: requests.Session):
        """Создание пользователя с Unicode символами в full_name."""
        unicode_name = "Тестовый Пользователь 测试用户"
        user_data = create_test_user_data(full_name=unicode_name)

        response = api_client.post("/users", json=user_data)

        assert response.status_code == 201
        user = response.json()
        assert user["full_name"] == unicode_name

        # Cleanup
        api_client.delete(f"/users/{user['id']}")

    @pytest.mark.parametrize("skip,limit", [
        (0, 1),       # Минимальный limit
        (1000, 100),  # Большой offset
    ])
    def test_get_users_pagination_boundaries(
        self,
        api_client: requests.Session,
        multiple_users,
        skip: int,
        limit: int
    ):
        """Тестирование граничных значений пагинации."""
        response = api_client.get("/users", params={"skip": skip, "limit": limit})

        assert response.status_code == 200
        users = response.json()
        assert isinstance(users, list)
        # При большом skip может вернуться пустой список
        if skip > len(multiple_users):
            assert len(users) == 0

    def test_update_user_same_values(self, api_client: requests.Session, created_user):
        """Обновление пользователя на те же самые значения (идемпотентность)."""
        user_id = created_user["id"]
        same_data = {
            "email": created_user["email"],
            "username": created_user["username"],
            "full_name": created_user["full_name"]
        }

        response = api_client.put(f"/users/{user_id}", json=same_data)

        assert response.status_code == 200
        updated_user = response.json()
        assert updated_user["email"] == created_user["email"]
        assert updated_user["username"] == created_user["username"]

    def test_update_user_partial_unicode(self, api_client: requests.Session, created_user):
        """Обновление только full_name с Unicode символами."""
        user_id = created_user["id"]
        unicode_update = {"full_name": "Новое Имя 新名字"}

        response = api_client.put(f"/users/{user_id}", json=unicode_update)

        assert response.status_code == 200
        updated_user = response.json()
        assert updated_user["full_name"] == unicode_update["full_name"]

    def test_concurrent_user_creation_same_email(self, api_client: requests.Session):
        """
        Симуляция одновременного создания пользователей с одинаковым email.
        Только один должен успешно создаться.
        """
        import concurrent.futures

        same_email = "concurrent@example.com"

        def create_user_with_email():
            user_data = create_test_user_data(email=same_email)
            try:
                response = api_client.post("/users", json=user_data)
                return response.status_code, response.json()
            except Exception as e:
                return None, str(e)

        # Запускаем 5 одновременных запросов
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(create_user_with_email) for _ in range(5)]
            results = [f.result() for f in futures]

        # Проверяем результаты
        success_count = sum(1 for status, _ in results if status == 201)
        failure_count = sum(1 for status, _ in results if status == 400)

        assert success_count == 1, "Only one user should be created successfully"
        assert failure_count == 4, "Four requests should fail with duplicate email"

        # Cleanup: находим и удаляем созданного пользователя
        for status, data in results:
            if status == 201 and isinstance(data, dict) and "id" in data:
                api_client.delete(f"/users/{data['id']}")
                break
