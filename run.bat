@echo off
setlocal EnableExtensions EnableDelayedExpansion

title FireTV Remapper - Watchdog
color 0A

rem ===== Configuration =====
set "IP_ADDRESS=192.168.1.16:5555"
set "CHECK_INTERVAL=10"
set "OFFLINE_INTERVAL=20"
set "FAIL_CONFIRMATIONS=2"
set "HEARTBEAT_TIMEOUT=25"
set "REMOTE_SCRIPT=/sdcard/firetv-remapper.sh"
set "REMOTE_LOG=/sdcard/firetv-remapper.log"
set "REMOTE_PID=/sdcard/firetv-remapper.pid"
set "REMOTE_HEARTBEAT=/sdcard/firetv-remapper.heartbeat"
set "REMOTE_STATE=/sdcard/firetv-remapper.state"
set "REMOTE_LOCK=/sdcard/firetv-remapper.lock"

set /a BAD_COUNT=0
set /a RESTART_COUNT=0

call :connect
if errorlevel 1 goto initial_offline
call :ensure_started

:initial_offline
goto main_loop

:main_loop
call :connect
if errorlevel 1 goto adb_offline

call :health
if not errorlevel 1 goto service_healthy

set /a BAD_COUNT+=1
if !BAD_COUNT! LSS %FAIL_CONFIRMATIONS% goto health_failure_pending

echo [%TIME%] Confirmed failure; restarting the remote service.
call :restart_service
set /a BAD_COUNT=0
set /a RESTART_COUNT+=1
echo [%TIME%] Recovery complete. Restarts: !RESTART_COUNT!.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:adb_offline
set /a BAD_COUNT=0
echo [%TIME%] ADB unavailable; retrying connection in %OFFLINE_INTERVAL% seconds.
timeout /t %OFFLINE_INTERVAL% /nobreak >nul
goto main_loop

:service_healthy
if !BAD_COUNT! GTR 0 (
    echo [%TIME%] Service recovered; transient failure ignored.
    set /a BAD_COUNT=0
) else (
    echo [%TIME%] Healthy: script, heartbeat and capture active.
)
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:health_failure_pending
echo [%TIME%] Provisional health failure (!BAD_COUNT!/%FAIL_CONFIRMATIONS%); awaiting confirmation.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:connect
adb start-server >nul 2>&1
adb connect %IP_ADDRESS% >nul 2>&1
adb -s %IP_ADDRESS% get-state >nul 2>&1
exit /b %errorlevel%

:health
rem If getevent freezes or the remote process dies, the heartbeat ages out.
adb -s %IP_ADDRESS% shell "NOW=$(date +%%s); HB=$(cat %REMOTE_HEARTBEAT% 2>/dev/null); PID=$(cat %REMOTE_PID% 2>/dev/null); STATE=$(cat %REMOTE_STATE% 2>/dev/null); [ -n \"$PID\" ] && kill -0 $PID 2>/dev/null && [ -n \"$HB\" ] && [ $((NOW-HB)) -le %HEARTBEAT_TIMEOUT% ] && [ \"$STATE\" = \"MONITORING\" -o \"$STATE\" = \"WAITING_DEVICE\" -o \"$STATE\" = \"RECOVERING_DEVICE\" ]"
if errorlevel 1 exit /b 1
exit /b 0

:ensure_started
adb -s %IP_ADDRESS% shell "test -f %REMOTE_SCRIPT%" >nul 2>&1
if errorlevel 1 goto script_missing
adb -s %IP_ADDRESS% shell "chmod +x %REMOTE_SCRIPT% && sed -i 's/\r//g' %REMOTE_SCRIPT%" >nul 2>&1
rem Always replaces the previous instance when starting this watchdog.
call :restart_service
exit /b 0

:script_missing
echo [%TIME%] Script not found on the Fire TV. Upload firetv-remapper.sh to %REMOTE_SCRIPT%.
exit /b 1

:restart_service
rem Kills all old copies of the remapper and starts a fresh instance.
adb -s %IP_ADDRESS% shell "for P in $(ps 2>/dev/null | awk 'NR>1 && $0 ~ /[f]iretv-remapper\.sh/ {print $1}'); do kill $P 2>/dev/null; done" >nul 2>&1
adb -s %IP_ADDRESS% shell "killall getevent" >nul 2>&1
adb -s %IP_ADDRESS% shell "rm -f %REMOTE_LOCK% %REMOTE_HEARTBEAT% %REMOTE_STATE%" >nul 2>&1
rem The log is appended (>>) instead of truncated (>) so a restart never clears the history.
adb -s %IP_ADDRESS% shell "nohup sh %REMOTE_SCRIPT% >> %REMOTE_LOG% 2>&1 &" >nul 2>&1
exit /b 0
