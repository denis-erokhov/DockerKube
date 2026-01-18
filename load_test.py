import requests
import time
import random

API_URL = "http://localhost:8000/users"

print("🔥 Запуск нагрузочного тестирования...")
print("Генерируем запросы с ошибками и без\n")

for i in range(20):
  payload = {
      "email": f"test{i}@example.com",
      "username": f"user{i}",
      "full_name": f"Test User {i}"
  }

  if random.random() < 0.3:
      bug_type = random.choice(['invalid_email', 'missing_field', 'duplicate'])

      if bug_type == 'invalid_email':
          payload["email"] = f"invalid-email-{i}"
          print(f"❌ Запрос {i}: НЕВАЛИДНЫЙ EMAIL")
      elif bug_type == 'missing_field':
          del payload["username"]
          print(f"❌ Запрос {i}: ОТСУТСТВУЕТ USERNAME")
      else:
          payload["email"] = "duplicate@example.com"
          print(f"❌ Запрос {i}: ДУБЛИКАТ EMAIL")
  else:
      print(f"✅ Запрос {i}: OK")

  try:
      response = requests.post(API_URL, json=payload)
      print(f"   Ответ: {response.status_code}")

      if response.status_code >= 400:
          print(f"   Ошибка: {response.json()}")
  except Exception as e:
      print(f"   EXCEPTION: {e}")

  print()
  time.sleep(0.3)

print("✅ Нагрузочное тестирование завершено!")