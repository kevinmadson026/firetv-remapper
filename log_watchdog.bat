@echo off
setlocal EnableExtensions

set "IP_ADDRESS=%~1"
set "REMOTE_LOG=%~2"
if not defined IP_ADDRESS set "IP_ADDRESS=192.168.1.16:5555"
if not defined REMOTE_LOG set "REMOTE_LOG=/sdcard/firetv-remapper.log"

rem Este script e executado em segundo plano pelo run.bat, sem abrir outra janela.
title FireTV Remapper - Unified Watchdog Log
color 0A

echo [%TIME%] Monitor unificado iniciado para %IP_ADDRESS%.
echo [%TIME%] Eventos monitorados: event4 e event5.
echo [%TIME%] Quando houver clique, o botao identificado pelo remapper sera exibido exatamente como registrado no log remoto.

:loop
adb start-server >nul 2>&1
adb connect %IP_ADDRESS% >nul 2>&1
adb -s %IP_ADDRESS% get-state >nul 2>&1
if errorlevel 1 (
    echo [%TIME%] ADB indisponivel; nova tentativa em 5 segundos.
    timeout /t 5 /nobreak >nul
    goto loop
)

echo [%TIME%] Conectado; acompanhando %REMOTE_LOG%.
adb -s %IP_ADDRESS% shell tail -f %REMOTE_LOG%

echo [%TIME%] Sessao do log terminou (terminated); reconectando automaticamente.
timeout /t 3 /nobreak >nul
goto loop
