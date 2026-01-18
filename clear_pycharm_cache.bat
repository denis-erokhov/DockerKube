@echo off
REM ========================================
REM Скрипт для очистки кэшей PyCharm
REM Автоматически очищает временные файлы и кэши
REM для улучшения производительности
REM ========================================

echo ========================================
echo Очистка кэшей PyCharm 2025.2
echo ========================================
echo.

REM Проверка, запущен ли PyCharm
tasklist /FI "IMAGENAME eq pycharm64.exe" 2>NUL | find /I /N "pycharm64.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [ОШИБКА] PyCharm запущен! Закройте PyCharm перед очисткой кэшей.
    echo.
    pause
    exit /b 1
)

echo [1/5] Очистка кэша системы...
if exist "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\caches" (
    rmdir /s /q "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\caches"
    echo ✓ Кэш системы очищен
) else (
    echo ℹ Кэш системы не найден
)

echo.
echo [2/5] Очистка временных файлов...
if exist "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\tmp" (
    rmdir /s /q "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\tmp"
    echo ✓ Временные файлы удалены
) else (
    echo ℹ Временные файлы не найдены
)

echo.
echo [3/5] Очистка логов...
if exist "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\log" (
    rmdir /s /q "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\log"
    echo ✓ Логи очищены
) else (
    echo ℹ Логи не найдены
)

echo.
echo [4/5] Очистка индексов (опционально - будут пересозданы при запуске)...
if exist "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\index" (
    rmdir /s /q "%LOCALAPPDATA%\JetBrains\PyCharm2025.2\index"
    echo ✓ Индексы очищены
) else (
    echo ℹ Индексы не найдены
)

echo.
echo [5/5] Очистка кэшей проекта DockerKube...
cd /d "%~dp0"

if exist ".pytest_cache" (
    rmdir /s /q ".pytest_cache"
    echo ✓ Pytest cache удален
)

if exist "__pycache__" (
    rmdir /s /q "__pycache__"
    echo ✓ __pycache__ удален
)

if exist "htmlcov" (
    rmdir /s /q "htmlcov"
    echo ✓ Coverage reports удалены
)

if exist ".coverage" (
    del /f /q ".coverage"
    echo ✓ .coverage удален
)

REM Рекурсивная очистка __pycache__ во всех подпапках
for /d /r . %%d in (__pycache__) do @if exist "%%d" (
    rmdir /s /q "%%d" 2>NUL
    echo ✓ Удалено: %%d
)

echo.
echo ========================================
echo ✅ Очистка завершена успешно!
echo ========================================
echo.
echo 💡 Рекомендации:
echo    1. Запустите PyCharm
echo    2. При первом запуске будет пересоздан индекс (может занять 1-2 минуты)
echo    3. Используйте этот скрипт раз в неделю для профилактики
echo.
pause
