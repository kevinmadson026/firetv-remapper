@echo off
title FireTV Remapper - Gerenciador
color 0C

:: 1. Garante a conexao ADB primeiro
adb connect 192.168.1.7:5555 >nul 2>&1

:: Fecha o Prime Video e Netflix antes de iniciar tudo
echo Fechando Prime Video e Netflix...
adb -s 192.168.1.7:5555 shell "am force-stop com.amazon.avod" >nul 2>&1
adb -s 192.168.1.7:5555 shell "am force-stop com.netflix.ninja" >nul 2>&1

:: 2. Dá permissao de execução e limpa caracteres do Windows (CRLF para LF)
echo Configurando permissoes e formato do script no Fire TV...
adb -s 192.168.1.7:5555 shell "chmod +x /sdcard/firetv-remapper.sh && sed -i 's/\r//g' /sdcard/firetv-remapper.sh" >nul 2>&1

:: 3. Cria o arquivo de log vazio e limpa instancias antigas
adb -s 192.168.1.7:5555 shell "touch /sdcard/firetv-remapper.log; pkill -f firetv-remapper; pkill -f getevent" >nul 2>&1

:: 4. Inicia o script redirecionando a saida para o log em segundo plano
adb -s 192.168.1.7:5555 shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"

:: 5. Abre uma nova janela separada APENAS UMA VEZ com o log em tempo real
start "FireTV - Log em Tempo Real" cmd /k "adb -s 192.168.1.7:5555 shell tail -f /sdcard/firetv-remapper.log"

:loop
cls
echo [%TIME%] Verificando conexao e status no Fire TV...

:: Garante a conexao ADB via rede
adb connect 192.168.1.7:5555 >nul 2>&1

:: Reseta a variavel de status
set STATUS=OK

:: Verifica se o script principal esta rodando
adb -s 192.168.1.7:5555 shell "pgrep -f firetv-remapper.sh" >nul 2>&1
if errorlevel 1 set STATUS=ERRO

:: Verifica se o getevent esta rodando
adb -s 192.168.1.7:5555 shell "pgrep -f getevent" >nul 2>&1
if errorlevel 1 set STATUS=ERRO

:: Processa a decisao com base nos testes (CORRIGIDO: Aponta corretamente para o .sh)
if "%STATUS%"=="ERRO" (
    echo [%TIME%] Script ou getevent parou. Reiniciando...
    adb -s 192.168.1.7:5555 shell "pkill -f firetv-remapper; pkill -f getevent" >nul 2>&1
    adb -s 192.168.1.7:5555 shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"
) else (
    echo [%TIME%] Script e getevent estao rodando perfeitamente.
)

:: Aguarda 30 segundos antes de verificar novamente
timeout /t 30 /nobreak >nul
goto loop