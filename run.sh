#!/bin/bash

# ===== Configuração =====
IP_ADDRESS="192.168.1.16:5555"
CHECK_INTERVAL=3
OFFLINE_INTERVAL=15
FAIL_CONFIRMATIONS=2
ALIVE_TIMEOUT=6

REMOTE_SCRIPT="/sdcard/firetv-remapper.sh"
REMOTE_LOG="/sdcard/firetv-remapper.log"
REMOTE_PID="/sdcard/firetv-remapper.pid"
REMOTE_STATE="/sdcard/firetv-remapper.state"
REMOTE_LOCK="/sdcard/firetv-remapper.lock"
REMOTE_ALIVE="/sdcard/firetv-remapper.alive"
REMOTE_LOOPSTART="/sdcard/firetv-remapper.loopstart"

BAD_COUNT=0
RESTART_COUNT=0

connect_adb() {
    adb start-server >/dev/null 2>&1
    adb connect "$IP_ADDRESS" >/dev/null 2>&1
    adb -s "$IP_ADDRESS" get-state >/dev/null 2>&1
    return $?
}

check_health() {
    adb -s "$IP_ADDRESS" shell "NOW=\$(date +%s); ALIVE=\$(cat $REMOTE_ALIVE 2>/dev/null); PID=\$(cat $REMOTE_PID 2>/dev/null); STATE=\$(cat $REMOTE_STATE 2>/dev/null); [ -n \"\$ALIVE\" ] && [ \$((\$NOW-\$ALIVE)) -le $ALIVE_TIMEOUT ] && [ -n \"\$PID\" ] && kill -0 \$PID 2>/dev/null && [ \"\$STATE\" = \"MONITORING\" -o \"\$STATE\" = \"WAITING_DEVICE\" -o \"\$STATE\" = \"RECOVERING_DEVICE\" ]"
    return $?
}

is_busy() {
    adb -s "$IP_ADDRESS" shell "test -e $REMOTE_LOCK"
    return $?
}

restart_service() {
    adb -s "$IP_ADDRESS" shell "killall sh" >/dev/null 2>&1
    adb -s "$IP_ADDRESS" shell "killall getevent" >/dev/null 2>&1
    adb -s "$IP_ADDRESS" shell "rm -f $REMOTE_LOCK $REMOTE_STATE $REMOTE_ALIVE $REMOTE_LOOPSTART" >/dev/null 2>&1
    adb -s "$IP_ADDRESS" shell "nohup sh $REMOTE_SCRIPT > $REMOTE_LOG 2>&1 &" >/dev/null 2>&1
    return $?
}

ensure_started() {
    adb -s "$IP_ADDRESS" shell "test -f $REMOTE_SCRIPT" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[$(date +%T)] Script não encontrado no Fire TV. Envie firetv-remapper.sh para $REMOTE_SCRIPT."
        exit 1
    fi
    adb -s "$IP_ADDRESS" shell "chmod +x $REMOTE_SCRIPT && sed -i 's/\r//g' $REMOTE_SCRIPT" >/dev/null 2>&1
    restart_service
}

# Início do Script
connect_adb
if [ $? -eq 0 ]; then
    ensure_started
else
    echo "[$(date +%T)] Inicialmente offline. Aguardando conexão..."
fi

while true; do
    connect_adb
    if [ $? -ne 0 ]; then
        BAD_COUNT=0
        echo "[$(date +%T)] ADB indisponível; tentando reconectar em $OFFLINE_INTERVAL segundos."
        sleep $OFFLINE_INTERVAL
        continue
    fi

    check_health
    if [ $? -eq 0 ]; then
        if [ $BAD_COUNT -gt 0 ]; then
            echo "[$(date +%T)] Serviço recuperado; falha temporária ignorada."
        fi
        BAD_COUNT=0
        sleep $CHECK_INTERVAL
        continue
    fi

    BAD_COUNT=$((BAD_COUNT + 1))
    if [ $BAD_COUNT -lt $FAIL_CONFIRMATIONS ]; then
        echo "[$(date +%T)] Falha de saúde provisória ($BAD_COUNT/$FAIL_CONFIRMATIONS); aguardando confirmação."
        sleep $CHECK_INTERVAL
        continue
    fi

    is_busy
    if [ $? -eq 0 ]; then
        echo "[$(date +%T)] Operação de botão em andamento; recuperação adiada."
        sleep $CHECK_INTERVAL
        continue
    fi

    echo "[$(date +%T)] Falha confirmada; reiniciando apenas o serviço remoto."
    restart_service
    BAD_COUNT=0
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "[$(date +%T)] Recuperação concluída. Reinicializações: $RESTART_COUNT."
    sleep $CHECK_INTERVAL
done
