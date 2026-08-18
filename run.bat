@echo off
setlocal EnableExtensions EnableDelayedExpansion

title FireTV Remapper - Aggressive Health Watchdog
color 0A

rem ===== Configuration =====
rem CHECK_INTERVAL : how often (seconds) the Windows side probes the device.
rem OFFLINE_INTERVAL: wait before retrying when ADB itself is unreachable.
rem FAIL_CONFIRMATIONS: consecutive failed probes before restarting the service.
rem   Detection time (worst case) = CHECK_INTERVAL * FAIL_CONFIRMATIONS.
rem   With 3s * 2 = 6s max until the restart command is issued.
rem ALIVE_TIMEOUT: max allowed age (seconds) of firetv-remapper.alive.
rem   If the remote script or its alive pulse dies/stalls, run.bat restarts it.
rem LOOP_TIMEOUT_WARN: max allowed age (seconds) of firetv-remapper.loopstart
rem   before reporting the main loop is stuck (informational; the stuck guard
rem   inside the sh kills the blocked getevent on its own after LOOP_TIMEOUT=15s).

set "IP_ADDRESS=192.168.1.16:5555"
set "CHECK_INTERVAL=3"
set "OFFLINE_INTERVAL=15"
set "FAIL_CONFIRMATIONS=2"
set "ALIVE_TIMEOUT=6"
set "LOOP_TIMEOUT_WARN=20"
set "REMOTE_SCRIPT=/sdcard/firetv-remapper.sh"
set "REMOTE_LOG=/sdcard/firetv-remapper.log"
set "REMOTE_PID=/sdcard/firetv-remapper.pid"
set "REMOTE_HEARTBEAT=/sdcard/firetv-remapper.heartbeat"
set "REMOTE_STATE=/sdcard/firetv-remapper.state"
set "REMOTE_LOCK=/sdcard/firetv-remapper.lock"
set "REMOTE_ALIVE=/sdcard/firetv-remapper.alive"
set "REMOTE_LOOPSTART=/sdcard/firetv-remapper.loopstart"
set "SCRIPT_DIR=%~dp0"
set "LOG_WATCHDOG=%SCRIPT_DIR%log_watchdog.bat"

set /a BAD_COUNT=0
set /a RESTART_COUNT=0

call :connect
if errorlevel 1 goto initial_offline
call :ensure_started

:initial_offline
rem The log monitor reconnects on its own when the ADB session ends.
if exist "%LOG_WATCHDOG%" (
    start "FireTV - Real-Time Log" cmd /k call "%LOG_WATCHDOG%" "%IP_ADDRESS%" "%REMOTE_LOG%"
) else (
    echo [%TIME%] WARNING: %LOG_WATCHDOG% was not found; automatic logging disabled.
)

goto main_loop

:main_loop
call :connect
if errorlevel 1 goto adb_offline

call :health
if not errorlevel 1 goto service_healthy

set /a BAD_COUNT+=1
if !BAD_COUNT! LSS %FAIL_CONFIRMATIONS% goto health_failure_pending

call :is_busy
if not errorlevel 1 goto button_in_progress

echo [%TIME%] Failure confirmed; restarting only the remote service.
call :restart_service
set /a BAD_COUNT=0
set /a RESTART_COUNT+=1
echo [%TIME%] Recovery complete. Restarts: !RESTART_COUNT!.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:adb_offline
set /a BAD_COUNT=0
echo [%TIME%] ADB unavailable; trying to reconnect in %OFFLINE_INTERVAL% seconds.
timeout /t %OFFLINE_INTERVAL% /nobreak >nul
goto main_loop

:service_healthy
if !BAD_COUNT! GTR 0 echo [%TIME%] Service recovered; transient failure ignored.
set /a BAD_COUNT=0
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:health_failure_pending
echo [%TIME%] Provisional health failure (!BAD_COUNT!/%FAIL_CONFIRMATIONS%); awaiting confirmation.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:button_in_progress
echo [%TIME%] Button operation in progress; recovery deferred.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:connect
adb start-server >nul 2>&1
adb connect %IP_ADDRESS% >nul 2>&1
adb -s %IP_ADDRESS% get-state >nul 2>&1
exit /b %errorlevel%

:health
rem The ALIVE pulse is the aggressive watchdog signal: firetv-remapper.alive
rem must be refreshed every second by the remote script. If its age exceeds
rem ALIVE_TIMEOUT, the script (or its getevent) is considered dead/stuck and
rem run.bat restarts the service within seconds.
adb -s %IP_ADDRESS% shell "NOW=$(date +%%s); ALIVE=$(cat %REMOTE_ALIVE% 2>/dev/null); PID=$(cat %REMOTE_PID% 2>/dev/null); STATE=$(cat %REMOTE_STATE% 2>/dev/null); LOOPSTART=$(cat %REMOTE_LOOPSTART% 2>/dev/null); [ -n "$ALIVE" ] && [ $((NOW-ALIVE)) -le %ALIVE_TIMEOUT% ] && [ -n "$PID" ] && kill -0 $PID 2>/dev/null && [ "$STATE" = "MONITORING" -o "$STATE" = "WAITING_DEVICE" -o "$STATE" = "RECOVERING_DEVICE" ]"
if errorlevel 1 exit /b 1
exit /b 0

:is_busy
adb -s %IP_ADDRESS% shell "test -e %REMOTE_LOCK%"
exit /b %errorlevel%

:ensure_started
adb -s %IP_ADDRESS% shell "test -f %REMOTE_SCRIPT%" >nul 2>&1
if errorlevel 1 goto script_missing
adb -s %IP_ADDRESS% shell "chmod +x %REMOTE_SCRIPT% && sed -i 's/\r//g' %REMOTE_SCRIPT%" >nul 2>&1
rem Always replaces the previous instance when starting this watchdog.
call :restart_service
exit /b 0

:script_missing
echo [%TIME%] Script not found on the Fire TV. Push firetv-remapper.sh to %REMOTE_SCRIPT%.
exit /b 1

:restart_service
rem The remote PID/lock prevents two remapper instances from coexisting.
adb -s %IP_ADDRESS% shell "killall sh" >nul 2>&1
adb -s %IP_ADDRESS% shell "killall getevent" >nul 2>&1
adb -s %IP_ADDRESS% shell "rm -f %REMOTE_LOCK% %REMOTE_HEARTBEAT% %REMOTE_STATE% %REMOTE_ALIVE% %REMOTE_LOOPSTART%" >nul 2>&1
adb -s %IP_ADDRESS% shell "nohup sh %REMOTE_SCRIPT% > %REMOTE_LOG% 2>&1 &" >nul 2>&1
exit /b 0
