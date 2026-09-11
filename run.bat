@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Relaunch in a persistent Command Prompt when started by double-click.
if /I not "%~1"=="__RUNNER" (
    start "FireTV Remapper" "%ComSpec%" /k call "%~f0" __RUNNER
    exit /b 0
)

title FireTV Remapper - Aggressive Health Watchdog
color 0A

rem ===== Configuration =====
rem Replace this address with your Fire TV IP address.
set "IP_ADDRESS=192.168.1.14:5555"
set "CHECK_INTERVAL=5"
set "OFFLINE_INTERVAL=15"
set "FAIL_CONFIRMATIONS=3"
set "ALIVE_TIMEOUT=15"
set "LOOP_TIMEOUT=20"

set "REMOTE_SCRIPT=/sdcard/firetv-remapper.sh"
set "REMOTE_LOG=/sdcard/firetv-remapper.log"
set "REMOTE_PID=/sdcard/firetv-remapper.pid"
set "REMOTE_HEARTBEAT=/sdcard/firetv-remapper.heartbeat"
set "REMOTE_STATE=/sdcard/firetv-remapper.state"
set "REMOTE_LOCK=/sdcard/firetv-remapper.lock"
set "REMOTE_ALIVE=/sdcard/firetv-remapper.alive"
set "REMOTE_LOOPSTART=/sdcard/firetv-remapper.loopstart"

set "SCRIPT_DIR=%~dp0"
set "LOCAL_SCRIPT=%SCRIPT_DIR%firetv-remapper.sh"
set "LOG_WATCHDOG=%SCRIPT_DIR%log_watchdog.bat"
set "DEBUG_LOG=%SCRIPT_DIR%run-debug.log"

cd /d "%SCRIPT_DIR%"

echo.>>"%DEBUG_LOG%"
echo [%DATE% %TIME%] Launcher started.>>"%DEBUG_LOG%"

set /a BAD_COUNT=0
set /a RESTART_COUNT=0

call :connect
if errorlevel 1 goto initial_offline
call :ensure_started
if errorlevel 1 goto startup_failed

goto start_log_watchdog

:initial_offline
echo [%TIME%] Fire TV is offline or not authorized for ADB.
echo [%TIME%] Confirm IP_ADDRESS, network connection, and the USB debugging authorization dialog.
echo [%TIME%] The launcher will keep running and retry the connection.
echo [%DATE% %TIME%] Initial ADB connection failed.>>"%DEBUG_LOG%"

goto start_log_watchdog

:startup_failed
echo [%TIME%] The service could not be started.
echo [%TIME%] Check the error above, confirm that firetv-remapper.sh is next to run.bat, and verify the Fire TV connection.
echo [%DATE% %TIME%] Service startup failed.>>"%DEBUG_LOG%"
pause
goto start_log_watchdog

:start_log_watchdog
if not exist "%LOG_WATCHDOG%" goto log_watchdog_missing
rem Close an older log window so multiple run.bat launches do not duplicate output.
taskkill /FI "WINDOWTITLE eq FireTV - Real-Time Log Watchdog" /T /F >nul 2>&1
start "FireTV - Real-Time Log" "%ComSpec%" /k call "%LOG_WATCHDOG%" "%IP_ADDRESS%" "%REMOTE_LOG%"
goto main_loop

:log_watchdog_missing
echo [%TIME%] WARNING: %LOG_WATCHDOG% was not found; automatic logging disabled.

goto main_loop

:main_loop
rem If the screen is off or the Fire TV is in standby, do not wake it just for a health check.
call :is_screen_on
if errorlevel 1 (
    set /a BAD_COUNT=0
    timeout /t %CHECK_INTERVAL% /nobreak >nul
    goto main_loop
)

rem Test service health without reconnecting ADB on every iteration.
call :health
if not errorlevel 1 goto service_healthy

rem If health failed, check whether the ADB connection is still available.
call :connect
if errorlevel 1 goto adb_offline

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
timeout /t 1 /nobreak >nul
rem Lightweight device check to confirm that the Fire TV is connected and authorized.
adb devices | findstr /R /C:"%IP_ADDRESS%.*device$" >nul 2>&1
exit /b %errorlevel%

:health
adb -s %IP_ADDRESS% shell "NOW=$(date +%%s); ALIVE=$(cat %REMOTE_ALIVE% 2>/dev/null || echo 0); PID=$(cat %REMOTE_PID% 2>/dev/null || echo 0); STATE=$(cat %REMOTE_STATE% 2>/dev/null); LOOP=$(cat %REMOTE_LOOPSTART% 2>/dev/null || echo 0); [ -n \"$ALIVE\" ] && [ $((NOW - ALIVE)) -le %ALIVE_TIMEOUT% ] && [ -n \"$PID\" ] && kill -0 $PID 2>/dev/null && case \"$STATE\" in MONITORING|WAITING_DEVICE|RECOVERING_DEVICE|SLEEPING) true ;; *) exit 1 ;; esac && { [ \"$STATE\" != MONITORING ] || [ $((NOW - LOOP)) -le %LOOP_TIMEOUT% ]; }" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:is_busy
adb -s %IP_ADDRESS% shell "test -e %REMOTE_LOCK%" >nul 2>&1
exit /b %errorlevel%

:ensure_started
if not exist "%LOCAL_SCRIPT%" (
    echo [%TIME%] Local script not found: "%LOCAL_SCRIPT%"
    exit /b 1
)

echo [%TIME%] Uploading firetv-remapper.sh to the Fire TV...
adb -s %IP_ADDRESS% push "%LOCAL_SCRIPT%" "%REMOTE_SCRIPT%" >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Failed to upload firetv-remapper.sh.
    echo [%TIME%] Verify that the Fire TV is connected and authorized with: adb devices
    exit /b 1
)

echo [%TIME%] Preparing the remote script and log file...
adb -s %IP_ADDRESS% shell "sed -i 's/\r//g' %REMOTE_SCRIPT% && chmod +x %REMOTE_SCRIPT% && touch %REMOTE_LOG%" >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Failed to prepare the remote script or log file.
    echo [%TIME%] Verify that ADB debugging is enabled and that %IP_ADDRESS% is reachable.
    exit /b 1
)

call :restart_service
exit /b %errorlevel%

:restart_service
rem Stop event capture and the old remapper before starting one fresh instance.
rem Kill every old remapper process and its child workers before starting.
adb -s %IP_ADDRESS% shell "killall getevent 2>/dev/null; kill_tree(){ for C in $(ps -o PID=,PPID= | awk -v P=$1 '$2==P{print $1}'); do kill_tree $C; done; kill -9 $1 2>/dev/null; }; for P in $(ps -o PID=,ARGS= | awk '/[f]iretv-remapper\.sh/{print $1}'); do kill_tree $P; done; killall getevent 2>/dev/null; rm -f %REMOTE_PID% %REMOTE_STATE% %REMOTE_ALIVE% %REMOTE_LOOPSTART% %REMOTE_LOCK%" >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Warning: could not fully stop the previous remapper; continuing.
)

adb -s %IP_ADDRESS% shell "rm -f %REMOTE_LOCK% %REMOTE_STATE% %REMOTE_ALIVE% %REMOTE_LOOPSTART% %REMOTE_PID%" >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Failed to remove stale remote state files.
    exit /b 1
)

adb -s %IP_ADDRESS% shell "touch %REMOTE_LOG%" >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Failed to create the remote log file.
    exit /b 1
)

rem The script terminates any previous remapper instance during its own startup.
adb -s %IP_ADDRESS% shell "nohup sh %REMOTE_SCRIPT% > %REMOTE_LOG% 2>&1 &" >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] Failed to launch the remote script.
    exit /b 1
)

exit /b 0

:is_screen_on
adb -s %IP_ADDRESS% shell "dumpsys power" | findstr /R /I /C:"mWakefulness=Awake" /C:"mWakefulness=Dreaming" /C:"Display Power: state=ON" >nul 2>&1
exit /b %errorlevel%
