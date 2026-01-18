"""
Утилита для логирования HTTP запросов и ответов в читаемом формате.
Помогает при отладке падающих тестов.
"""
import json
import logging
from typing import Optional
import requests

# Настраиваем базовый логгер
logger = logging.getLogger("api_tests")
logger.setLevel(logging.INFO)

# Создаём handler для вывода в консоль
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)

# Форматтер для красивого вывода
formatter = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)


def log_request(method: str, url: str, **kwargs):
    """
    Логирует HTTP запрос в читаемом формате.

    Args:
        method: HTTP метод (GET, POST, PUT, DELETE)
        url: URL запроса
        **kwargs: Дополнительные параметры (headers, json, params и т.д.)
    """
    logger.info(f"\n{'='*80}")
    logger.info(f"REQUEST: {method.upper()} {url}")

    if 'params' in kwargs and kwargs['params']:
        logger.info(f"Query params: {kwargs['params']}")

    if 'headers' in kwargs and kwargs['headers']:
        logger.info(f"Headers: {json.dumps(kwargs['headers'], indent=2)}")

    if 'json' in kwargs and kwargs['json']:
        logger.info(f"Body: {json.dumps(kwargs['json'], indent=2)}")


def log_response(response: requests.Response):
    """
    Логирует HTTP ответ в читаемом формате.

    Args:
        response: Объект Response от requests
    """
    logger.info(f"RESPONSE: {response.status_code} {response.reason}")
    logger.info(f"Response time: {response.elapsed.total_seconds():.3f}s")

    try:
        response_json = response.json()
        logger.info(f"Response body: {json.dumps(response_json, indent=2)}")
    except json.JSONDecodeError:
        logger.info(f"Response body (not JSON): {response.text}")

    logger.info(f"{'='*80}\n")


def log_curl_equivalent(method: str, url: str, **kwargs):
    """
    Логирует эквивалентную curl команду для воспроизведения запроса.
    Полезно для ручной отладки.

    Args:
        method: HTTP метод
        url: URL запроса
        **kwargs: Дополнительные параметры запроса
    """
    curl_parts = [f"curl -X {method.upper()}"]

    if 'headers' in kwargs and kwargs['headers']:
        for key, value in kwargs['headers'].items():
            curl_parts.append(f"-H '{key}: {value}'")

    if 'json' in kwargs and kwargs['json']:
        json_data = json.dumps(kwargs['json'])
        curl_parts.append(f"-d '{json_data}'")

    curl_parts.append(f"'{url}'")

    logger.info(f"CURL equivalent:\n{' '.join(curl_parts)}")
