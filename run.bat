@echo off
title FireTV Remapper - Gerenciador Inteligente
color 0C

:: Defina o IP do Fire TV aqui:
set IP_ADDRESS=192.168.1.7:5555

:: Contador para reinicialização preventiva (evita o travamento de 10 min)
set /a COUNTER=0

:: 1. Garante a conexao ADB primeiro
adb connect %IP_ADDRESS% >nul 2>&1

:: Fecha o Prime Video e Netflix antes de iniciar tudo
echo Fechando Prime Video e Netflix...
adb -s %IP_ADDRESS% shell "am force-stop com.amazon.firebat" >nul 2>&1
adb -s %IP_ADDRESS% shell "am force-stop com.netflix.ninja" >nul 2>&1

:: 2. Dá permissao de execução e limpa caracteres do Windows (CRLF para LF)
echo Configurando permissoes e formato do script no Fire TV...
adb -s %IP_ADDRESS% shell "chmod +x /sdcard/firetv-remapper.sh && sed -i 's/\r//g' /sdcard/firetv-remapper.sh" >nul 2>&1

:: 3. Cria o arquivo de log vazio e limpa instancias antigas
adb -s %IP_ADDRESS% shell "touch /sdcard/firetv-remapper.log; pkill -f firetv-remapper; pkill -f getevent" >nul 2>&1

:: 4. Inicia o script redirecionando a saida para o log em segundo plano
adb -s %IP_ADDRESS% shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"

:: 5. Abre uma nova janela separada APENAS UMA VEZ com o log em tempo real
start "FireTV - Log em Tempo Real" cmd /k "for /L %i in (1,0,2) do (adb connect 192.168.1.7:5555 & adb -s 192.168.1.7:5555 shell tail -f /sdcard/firetv-remapper.log & timeout /t 2)"
:: start "FireTV - Log em Tempo Real" cmd /k "adb -s %IP_ADDRESS% shell tail -f /sdcard/firetv-remapper.log"

:loop
cls
echo [%TIME%] Verificando conexao e status no Fire TV...

:: Garante a conexao ADB via rede
adb connect %IP_ADDRESS% >nul 2>&1

:: Reseta a variavel de status
set STATUS=OK

:: Verifica se o script principal esta rodando
adb -s %IP_ADDRESS% shell "pgrep -f firetv-remapper.sh" >nul 2>&1
if errorlevel 1 set STATUS=ERRO

:: Verifica se o getevent esta rodando
adb -s %IP_ADDRESS% shell "pgrep -f getevent" >nul 2>&1
if errorlevel 1 set STATUS=ERRO

:: Incrementa o contador (cada ciclo tem 30 segundos)
:: 10 ciclos * 30 segundos = 5 minutos
set /a COUNTER+=1
if %COUNTER% lss 10 goto prosseguir
echo [%TIME%] Realizando reinicializacao preventiva periodica (5 min)...
set STATUS=REINICIAR
set /a COUNTER=0

:prosseguir

:: Processa a decisao com base nos testes
if "%STATUS%"=="ERRO" (
    echo [%TIME%] Script ou getevent parou. Reiniciando...
    adb -s %IP_ADDRESS% shell "pkill -f firetv-remapper; pkill -f getevent" >nul 2>&1
    adb -s %IP_ADDRESS% shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"
) else if "%STATUS%"=="REINICIAR" (
    echo [%TIME%] Reiniciando o script preventivamente para evitar ociosidade do FireOS...
    adb -s %IP_ADDRESS% shell "pkill -f firetv-remapper; pkill -f getevent" >nul 2>&1
    adb -s %IP_ADDRESS% shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"
) else (
    echo [%TIME%] Script e getevent estao rodando perfeitamente. (Ciclo %COUNTER%/10)
)

:: Aguarda 30 segundos antes de verificar novamente
timeout /t 30 /nobreak >nul
goto loop
