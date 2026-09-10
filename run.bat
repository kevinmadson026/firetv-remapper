@echo off
setlocal EnableExtensions EnableDelayedExpansion

title FireTV Remapper - Aggressive Health Watchdog
color 0A

rem ===== Configuration =====
set "IP_ADDRESS=192.168.1.12:5555"
set "CHECK_INTERVAL=5"
set "OFFLINE_INTERVAL=15"
set "FAIL_CONFIRMATIONS=3"
set "ALIVE_TIMEOUT=15"
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
if exist "%LOG_WATCHDOG%" (
    start "FireTV - Real-Time Log" cmd /k call "%LOG_WATCHDOG%" "%IP_ADDRESS%" "%REMOTE_LOG%"
) else (
    echo [%TIME%] WARNING: %LOG_WATCHDOG% was not found; automatic logging disabled.
)

goto main_loop

:main_loop
rem Se a tela estiver desligada/standby, ignora a checagem para nao acordar a TV
call :is_screen_on
if errorlevel 1 (
    set /a BAD_COUNT=0
    timeout /t %CHECK_INTERVAL% /nobreak >nul
    goto main_loop
)

rem Testa a saude diretamente sem reconectar o ADB a cada iteracao
call :health
if not errorlevel 1 goto service_healthy

rem Se a saude falhou, verifica se a conexao ADB caiu antes de incrementar o BAD_COUNT
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
rem Lightweight device check (identical to .sh) to prevent waking up the TV
adb devices | findstr /R /C:"%IP_ADDRESS%.*device$" >nul 2>&1
exit /b %errorlevel%

:health
adb -s %IP_ADDRESS% shell "NOW=$(date +%%s); ALIVE=$(cat %REMOTE_ALIVE% 2>/dev/null || echo 0); PID=$(cat %REMOTE_PID% 2>/dev/null || echo 0); STATE=$(cat %REMOTE_STATE% 2>/dev/null); [ -n \"$ALIVE\" ] && [ $((NOW - ALIVE)) -le %ALIVE_TIMEOUT% ] && [ -n \"$PID\" ] && kill -0 $PID 2>/dev/null && case \"$STATE\" in MONITORING|WAITING_DEVICE|RECOVERING_DEVICE) exit 0 ;; *) exit 1 ;; esac" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:is_busy
adb -s %IP_ADDRESS% shell "test -e %REMOTE_LOCK%" >nul 2>&1
exit /b %errorlevel%

:ensure_started
adb -s %IP_ADDRESS% shell "test -f %REMOTE_SCRIPT%" >nul 2>&1
if errorlevel 1 goto script_missing
adb -s %IP_ADDRESS% shell "chmod +x %REMOTE_SCRIPT% && sed -i 's/\r//g' %REMOTE_SCRIPT%" >nul 2>&1
call :restart_service
exit /b 0

:script_missing
echo [%TIME%] Script not found on the Fire TV. Push firetv-remapper.sh to %REMOTE_SCRIPT%.
exit /b 1

:restart_service
rem Targeted termination by PID to avoid killing the shell or resetting temporary states globally
adb -s %IP_ADDRESS% shell "PID=\$(cat %REMOTE_PID% 2>/dev/null); [ -n \"\$PID\" ] && kill -9 \$PID 2>/dev/null; killall getevent 2>/dev/null; rm -f %REMOTE_LOCK% %REMOTE_STATE% %REMOTE_ALIVE% %REMOTE_LOOPSTART% %REMOTE_PID%; nohup sh %REMOTE_SCRIPT% > %REMOTE_LOG% 2>&1 &" >nul 2>&1
exit /b 0

:is_screen_on
adb -s %IP_ADDRESS% shell "dumpsys power" | findstr /I /C:"mWakefulness=Awake" >nul 2>&1
exit /b %errorlevel%