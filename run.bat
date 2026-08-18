@echo off
setlocal EnableExtensions EnableDelayedExpansion

title FireTV Remapper - Watchdog
color 0A

rem ===== Robustness =====
cd /d "%~dp0"
set "LOG_FILE=watchdog.log"
del "%LOG_FILE%" >nul 2>&1

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
set /a LOOP_COUNT=0

echo.> "%LOG_FILE%"
call :log "Watchdog started. Checking ADB availability..."

call :safety_check
call :connect
if errorlevel 1 (
    echo.
    echo Could not reach the Fire TV yet. The watchdog will keep retrying.
    echo [Press Ctrl+C to stop]
) else (
    call :ensure_started
)

:main_loop
set /a LOOP_COUNT+=1

call :connect
if errorlevel 1 goto adb_offline

call :health
if not errorlevel 1 goto service_healthy

set /a BAD_COUNT+=1
if !BAD_COUNT! LSS %FAIL_CONFIRMATIONS% goto health_failure_pending

call :log "Confirmed failure; restarting the remote service."
echo [!TIME!] Confirmed failure; restarting the remote service.
call :restart_service
set /a BAD_COUNT=0
set /a RESTART_COUNT+=1
call :log "Recovery complete. Restarts: !RESTART_COUNT!."
echo [!TIME!] Recovery complete. Restarts: !RESTART_COUNT!.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:adb_offline
set /a BAD_COUNT=0
call :log "ADB unavailable; retrying connection in %OFFLINE_INTERVAL% seconds."
echo [!TIME!] ADB unavailable; retrying connection in %OFFLINE_INTERVAL% seconds.
timeout /t %OFFLINE_INTERVAL% /nobreak >nul
goto main_loop

:service_healthy
if !BAD_COUNT! GTR 0 (
    call :log "Service recovered; transient failure ignored."
    echo [!TIME!] Service recovered; transient failure ignored.
    set /a BAD_COUNT=0
)
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:health_failure_pending
call :log "Provisional health failure (!BAD_COUNT!/%FAIL_CONFIRMATIONS%); awaiting confirmation."
echo [!TIME!] Provisional health failure (!BAD_COUNT!/%FAIL_CONFIRMATIONS%); awaiting confirmation.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

rem ================= Subroutines =================

:connect
rem Starts the ADB server and connects to the Fire TV.
rem Returns 0 when the device is reachable, 1 otherwise.
adb start-server >nul 2>&1
if errorlevel 1 (
    adb >nul 2>&1
    if errorlevel 9009 (
        echo [!TIME!] FATAL: adb.exe not found in PATH. Cannot continue.
        goto fatal
    )
    goto :eof
)
adb connect %IP_ADDRESS% >nul 2>&1
adb -s %IP_ADDRESS% get-state >nul 2>&1
exit /b %errorlevel%

:health
rem If getevent freezes or the remote process dies, the heartbeat ages out.
adb -s %IP_ADDRESS% shell "NOW=$(date +%%s); HB=$(cat %REMOTE_HEARTBEAT% 2>/dev/null); PID=$(cat %REMOTE_PID% 2>/dev/null); STATE=$(cat %REMOTE_STATE% 2>/dev/null); [ -n \"$PID\" ] ^&^& kill -0 $PID 2>/dev/null ^&^& [ -n \"$HB\" ] ^&^& [ $((NOW-HB)) -le %HEARTBEAT_TIMEOUT% ] ^&^& [ \"$STATE\" = \"MONITORING\" -o \"$STATE\" = \"WAITING_DEVICE\" -o \"$STATE\" = \"RECOVERING_DEVICE\" ]" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:ensure_started
adb -s %IP_ADDRESS% shell "test -f %REMOTE_SCRIPT%" >nul 2>&1
if errorlevel 1 goto script_missing
adb -s %IP_ADDRESS% shell "chmod +x %REMOTE_SCRIPT% && sed -i 's/\r//g' %REMOTE_SCRIPT%" >nul 2>&1
rem Always replaces the previous instance when starting this watchdog.
call :restart_service
goto :eof

:script_missing
call :log "FATAL: firetv-remapper.sh not found on the Fire TV. Cannot start service."
echo.
echo ERROR: firetv-remapper.sh was not found on the Fire TV.
echo Upload it first:  adb push firetv-remapper.sh %REMOTE_SCRIPT%
goto fatal

:restart_service
rem Kills all old copies of the remapper and starts a fresh instance.
adb -s %IP_ADDRESS% shell "for P in $(ps 2>/dev/null | awk 'NR^>1 ^&^& $0 ~ /[f]iretv-remapper\\.sh/ {print $1}'); do kill $P 2>/dev/null; done" >nul 2>&1
adb -s %IP_ADDRESS% shell "killall getevent" >nul 2>&1
adb -s %IP_ADDRESS% shell "rm -f %REMOTE_LOCK% %REMOTE_HEARTBEAT% %REMOTE_STATE%" >nul 2>&1
rem The log is appended (>>) instead of truncated (>) so a restart never clears the history.
adb -s %IP_ADDRESS% shell "nohup sh %REMOTE_SCRIPT% ^>^> %REMOTE_LOG% 2^>^&1 ^&" >nul 2>&1
goto :eof

rem ================= Safety routines =================

:safety_check
where adb >nul 2>&1
if errorlevel 1 (
    call :log "FATAL: ADB not found in PATH."
    echo.
    echo ERROR: adb.exe not found in PATH.
    echo Please install Android Platform Tools and add its folder to PATH,
    echo then double-click this file again.
    goto fatal
)
goto :eof

:log
rem Appends a timestamped line to the log file.
>> "%LOG_FILE%" echo [%DATE% %TIME%] %*
goto :eof

:fatal
echo.
echo The script stopped due to an error (see messages above).
echo A full log was saved to: %LOG_FILE%
echo.
echo Press any key to close...
pause >nul
exit /b 1
