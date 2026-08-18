@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "IP_ADDRESS=%~1"
set "REMOTE_LOG=%~2"
if not defined IP_ADDRESS set "IP_ADDRESS=192.168.1.16:5555"
if not defined REMOTE_LOG set "REMOTE_LOG=/sdcard/firetv-remapper.log"

title FireTV - Real-Time Log Watchdog
color 0B

echo [%TIME%] Log monitor started for %IP_ADDRESS%.

:reconnect
echo [%TIME%] Attempting to connect to %IP_ADDRESS%...
adb connect %IP_ADDRESS% >nul 2>&1
adb -s %IP_ADDRESS% get-state >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Device not ready. Retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto reconnect
)

echo [%TIME%] Connection established. Starting log stream...

:stream
rem O tail -f no Android às vezes para sem fechar o processo do shell.
rem Usamos um loop que verifica a saúde da conexão ADB periodicamente.
adb -s %IP_ADDRESS% shell "tail -f %REMOTE_LOG%"

rem Se o comando acima sair, significa que a sessão foi interrompida.
echo [%TIME%] WARNING: Log stream interrupted (Terminated).
echo [%TIME%] Checking device status...

adb -s %IP_ADDRESS% get-state >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Connection lost. Returning to reconnection loop.
    timeout /t 3 /nobreak >nul
    goto reconnect
) else (
    echo [%TIME%] Device is still online. Restarting stream in 2 seconds...
    timeout /t 2 /nobreak >nul
    goto stream
)
