@echo off
setlocal EnableExtensions

set "IP_ADDRESS=%~1"
set "REMOTE_LOG=%~2"
if not defined IP_ADDRESS set "IP_ADDRESS=192.168.1.16:5555"
if not defined REMOTE_LOG set "REMOTE_LOG=/sdcard/firetv-remapper.log"

title FireTV - Real-Time Log Watchdog
color 07

echo [%TIME%] Log monitor started for %IP_ADDRESS%.

:loop
adb start-server >nul 2>&1
adb connect %IP_ADDRESS% >nul 2>&1
adb -s %IP_ADDRESS% get-state >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] ADB unavailable; retrying in 5 seconds.
    timeout /t 5 /nobreak >nul
    goto loop
)

echo [%TIME%] Connected; following %REMOTE_LOG%.
adb -s %IP_ADDRESS% shell tail -f %REMOTE_LOG%

echo [%TIME%] Log session ended (terminated); reconnecting automatically.
timeout /t 3 /nobreak >nul
goto loop
