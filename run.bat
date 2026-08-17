@echo off
setlocal EnableExtensions EnableDelayedExpansion

title FireTV Remapper - Health Watchdog
color 0A

rem ===== Configuracao =====
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
rem Esta e a unica janela adicional: ela apenas acompanha o log remoto.
start "FireTV - Real-Time Log" cmd /k "adb -s %IP_ADDRESS% shell tail -f %REMOTE_LOG%"

:main_loop
call :connect
if errorlevel 1 goto adb_offline

call :health
if not errorlevel 1 goto service_healthy

set /a BAD_COUNT+=1
if !BAD_COUNT! LSS %FAIL_CONFIRMATIONS% goto health_failure_pending

call :is_busy
if not errorlevel 1 goto button_in_progress

echo [%TIME%] Falha confirmada; reiniciando apenas o servico remoto.
call :restart_service
set /a BAD_COUNT=0
set /a RESTART_COUNT+=1
echo [%TIME%] Recuperacao concluida. Reinicios: !RESTART_COUNT!.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:adb_offline
set /a BAD_COUNT=0
echo [%TIME%] ADB indisponivel; aguardando sem reiniciar nem despertar o Fire TV.
timeout /t %OFFLINE_INTERVAL% /nobreak >nul
goto main_loop

:service_healthy
if !BAD_COUNT! GTR 0 echo [%TIME%] Servico recuperado; falha transitoria ignorada.
set /a BAD_COUNT=0
echo [%TIME%] Saudavel: script, heartbeat e captura ativos.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:health_failure_pending
echo [%TIME%] Falha de saude provisoria (!BAD_COUNT!/%FAIL_CONFIRMATIONS%); aguardando confirmacao.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:button_in_progress
echo [%TIME%] Operacao de botao em andamento; recuperacao adiada.
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto main_loop

:connect
adb connect %IP_ADDRESS% >nul 2>&1
adb -s %IP_ADDRESS% get-state >nul 2>&1
exit /b %errorlevel%

:health
rem O heartbeat e atualizado pelo loop principal antes de chamar getevent.
rem Se getevent travar, o heartbeat envelhece e a falha e detectada.
adb -s %IP_ADDRESS% shell "NOW=$(date +%%s); HB=$(cat %REMOTE_HEARTBEAT% 2>/dev/null); PID=$(cat %REMOTE_PID% 2>/dev/null); STATE=$(cat %REMOTE_STATE% 2>/dev/null); [ -n \"$PID\" ] && kill -0 $PID 2>/dev/null && [ -n \"$HB\" ] && [ $((NOW-HB)) -le %HEARTBEAT_TIMEOUT% ] && [ \"$STATE\" = \"MONITORING\" -o \"$STATE\" = \"WAITING_DEVICE\" -o \"$STATE\" = \"RECOVERING_DEVICE\" ]"
if errorlevel 1 exit /b 1
exit /b 0

:is_busy
adb -s %IP_ADDRESS% shell "test -e %REMOTE_LOCK%"
exit /b %errorlevel%

:ensure_started
adb -s %IP_ADDRESS% shell "test -f %REMOTE_SCRIPT%" >nul 2>&1
if errorlevel 1 goto script_missing
adb -s %IP_ADDRESS% shell "chmod +x %REMOTE_SCRIPT% && sed -i 's/\r//g' %REMOTE_SCRIPT%" >nul 2>&1
call :health
if not errorlevel 1 exit /b 0
call :restart_service
exit /b 0

:script_missing
echo [%TIME%] Script nao encontrado no Fire TV. Envie firetv-remapper.sh para %REMOTE_SCRIPT%.
exit /b 1

:restart_service
rem O PID file identifica a instancia anterior sem matar o proprio comando ADB.
adb -s %IP_ADDRESS% shell "PID=$(cat %REMOTE_PID% 2>/dev/null); [ -z \"$PID\" ] || kill $PID 2>/dev/null; pkill -f 'getevent.*02e'; rm -f %REMOTE_LOCK% %REMOTE_HEARTBEAT% %REMOTE_STATE%" >nul 2>&1
adb -s %IP_ADDRESS% shell "nohup sh %REMOTE_SCRIPT% > %REMOTE_LOG% 2>&1 &" >nul 2>&1
exit /b 0
