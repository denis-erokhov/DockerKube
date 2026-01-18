# ========================================
# Скрипт мониторинга ресурсов PyCharm
# Показывает использование CPU и памяти
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Мониторинг ресурсов PyCharm" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Проверка, запущен ли PyCharm
$pycharm = Get-Process -Name "pycharm64" -ErrorAction SilentlyContinue

if ($null -eq $pycharm) {
    Write-Host "[❌] PyCharm не запущен" -ForegroundColor Red
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    exit
}

Write-Host "[✓] PyCharm запущен (PID: $($pycharm.Id))" -ForegroundColor Green
Write-Host ""

# Функция для форматирования размера памяти
function Format-ByteSize {
    param($Bytes)
    if ($Bytes -gt 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -gt 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } else {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
}

# Мониторинг в реальном времени
Write-Host "Обновление каждые 2 секунды. Нажмите Ctrl+C для выхода..." -ForegroundColor Yellow
Write-Host ""

while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Мониторинг ресурсов PyCharm" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Время: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""

    # Получаем свежие данные о процессе
    $pycharm = Get-Process -Name "pycharm64" -ErrorAction SilentlyContinue

    if ($null -eq $pycharm) {
        Write-Host "[❌] PyCharm был закрыт" -ForegroundColor Red
        break
    }

    # Память
    $memoryMB = $pycharm.WorkingSet64 / 1MB
    $memoryGB = $pycharm.WorkingSet64 / 1GB
    $privateMemoryGB = $pycharm.PrivateMemorySize64 / 1GB

    Write-Host "📊 Использование памяти:" -ForegroundColor White
    Write-Host "   Working Set:     " -NoNewline
    if ($memoryGB -gt 5) {
        Write-Host "$(Format-ByteSize $pycharm.WorkingSet64)" -ForegroundColor Red
        Write-Host "   ⚠️  ВЫСОКОЕ использование памяти!" -ForegroundColor Red
    } elseif ($memoryGB -gt 3) {
        Write-Host "$(Format-ByteSize $pycharm.WorkingSet64)" -ForegroundColor Yellow
    } else {
        Write-Host "$(Format-ByteSize $pycharm.WorkingSet64)" -ForegroundColor Green
    }

    Write-Host "   Private Memory:  $(Format-ByteSize $pycharm.PrivateMemorySize64)"
    Write-Host "   Virtual Memory:  $(Format-ByteSize $pycharm.VirtualMemorySize64)"
    Write-Host ""

    # CPU
    $cpu = $pycharm.CPU
    Write-Host "⚡ Использование CPU:" -ForegroundColor White
    Write-Host "   Общее время CPU: $([math]::Round($cpu, 2)) сек"
    Write-Host "   Потоков:         $($pycharm.Threads.Count)"
    Write-Host ""

    # Дополнительная информация
    Write-Host "ℹ️  Дополнительная информация:" -ForegroundColor White
    Write-Host "   PID:             $($pycharm.Id)"
    Write-Host "   Handles:         $($pycharm.HandleCount)"
    Write-Host "   Время запуска:   $($pycharm.StartTime.ToString('HH:mm:ss'))"
    $uptime = (Get-Date) - $pycharm.StartTime
    Write-Host "   Uptime:          $([math]::Floor($uptime.TotalHours))ч $($uptime.Minutes)м $($uptime.Seconds)с"
    Write-Host ""

    # Рекомендации
    if ($memoryGB -gt 5) {
        Write-Host "💡 Рекомендации:" -ForegroundColor Yellow
        Write-Host "   • Закройте ненужные вкладки и файлы" -ForegroundColor Yellow
        Write-Host "   • Используйте File → Invalidate Caches / Restart" -ForegroundColor Yellow
        Write-Host "   • Очистите терминал командой 'cls'" -ForegroundColor Yellow
        Write-Host "   • Запустите скрипт clear_pycharm_cache.bat" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Обновление через 2 секунды... (Ctrl+C для выхода)" -ForegroundColor Gray

    Start-Sleep -Seconds 2
}

Write-Host ""
Read-Host "Нажмите Enter для выхода"
