@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "IP_ADDRESS=%~1"
set "REMOTE_LOG=%~2"
set "POLL_INTERVAL=%~3"
if not defined IP_ADDRESS set "IP_ADDRESS=192.168.1.16:5555"
if not defined REMOTE_LOG set "REMOTE_LOG=/sdcard/firetv-remapper.log"
if not defined POLL_INTERVAL set "POLL_INTERVAL=5"

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

rem A plain "tail -f" can hold the stream open forever even when the remote
rem process silently stops writing (e.g. getevent freezes without logging).
rem Instead, we tail with a bounded wait (-s polling interval) and treat the
rem command's exit (or a kill -HUP on the ADB shell session) as a stall.
set "STALL_COUNT=0"
set "MAX_STALL=2"

:stream
rem "-s %POLL_INTERVAL%" makes tail wake up every N seconds instead of
rem blocking indefinitely, so a silent remote freeze surfaces quickly.
adb -s %IP_ADDRESS% shell "tail -c 0 -f %REMOTE_LOG% 2>/dev/null"

rem If the command above exits, the session or the file descriptor died.
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
