#!/usr/bin/env python3
"""
Скрипт нагрузочного тестирования API для генерации логов

Назначение:
    - Генерирует HTTP запросы к API для создания пользователей
    - Имитирует различные ошибки (невалидные email, дубликаты, и т.д.)
    - Используется для обучения анализу логов

Использование:
    python scripts/load_test.py

Требования:
    - API должно быть запущено на http://localhost:8000
    - pip install requests (уже есть в проекте)
"""

import requests
import time
import random
import string
from datetime import datetime


def generate_random_string(length=8):
    """Генерирует случайную строку"""
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))


def create_user_request(payload):
    """
    Отправляет POST запрос на создание пользователя

    Args:
        payload (dict): Данные пользователя

    Returns:
        tuple: (status_code, response_json_or_error)
    """
    try:
        response = requests.post(
            "http://localhost:8000/users",
            json=payload,
            timeout=5
        )
        return response.status_code, response.json()
    except requests.exceptions.RequestException as e:
        return None, str(e)


def main():
    """Основная функция для генерации нагрузки"""

    print("=" * 60)
    print("🚀 Запуск нагрузочного тестирования API")
    print(f"⏰ Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    print()

    total_requests = 20
    success_count = 0
    error_count = 0
    error_types = {}

    for i in range(total_requests):
        # Генерируем payload
        random_id = generate_random_string()
        payload = {
            "email": f"test{random_id}@example.com",
            "username": f"user{random_id}",
            "full_name": f"Test User {i}"
        }

        # ИМИТАЦИЯ РАЗЛИЧНЫХ ОШИБОК
        error_type = random.random()

        if error_type < 0.15:  # 15% - невалидный email
            payload["email"] = "invalid-email-without-at-sign"
            error_label = "INVALID_EMAIL"

        elif error_type < 0.25:  # 10% - пустой email
            payload["email"] = ""
            error_label = "EMPTY_EMAIL"

        elif error_type < 0.35:  # 10% - невалидный username (слишком короткий)
            payload["username"] = "ab"
            error_label = "SHORT_USERNAME"

        elif error_type < 0.45:  # 10% - дубликат email
            payload["email"] = "duplicate@example.com"
            error_label = "DUPLICATE_EMAIL"

        else:  # 55% - валидные данные
            error_label = "VALID"

        # Отправляем запрос
        status_code, response = create_user_request(payload)

        # Анализируем результат
        if status_code is None:
            print(f"❌ {i+1:02d}. CONNECTION_ERROR - {response}")
            error_count += 1
            error_types["CONNECTION_ERROR"] = error_types.get("CONNECTION_ERROR", 0) + 1

        elif 200 <= status_code < 300:
            print(f"✅ {i+1:02d}. {status_code} - {error_label} - {payload['email']}")
            success_count += 1

        else:
            print(f"❌ {i+1:02d}. {status_code} - {error_label} - {payload['email']}")
            error_count += 1

            # Подсчитываем типы ошибок
            error_key = f"{status_code}_{error_label}"
            error_types[error_key] = error_types.get(error_key, 0) + 1

        # Задержка между запросами
        time.sleep(0.5)

    # Итоговая статистика
    print()
    print("=" * 60)
    print("📊 ИТОГОВАЯ СТАТИСТИКА")
    print("=" * 60)
    print(f"Всего запросов:     {total_requests}")
    print(f"✅ Успешных:        {success_count} ({success_count/total_requests*100:.1f}%)")
    print(f"❌ Ошибок:          {error_count} ({error_count/total_requests*100:.1f}%)")
    print()

    if error_types:
        print("📋 Типы ошибок:")
        for error_type, count in sorted(error_types.items(), key=lambda x: -x[1]):
            print(f"  - {error_type}: {count}")

    print()
    print("=" * 60)
    print("✅ Нагрузочное тестирование завершено")
    print()
    print("💡 Следующие шаги:")
    print("   1. Посмотри логи backend: docker-compose logs backend")
    print("   2. Найди ошибки: docker-compose logs backend | grep -E '(ERROR|400|422|500)'")
    print("   3. Посчитай статистику: docker-compose logs backend | grep '422' | wc -l")
    print("=" * 60)


if __name__ == "__main__":
    main()
