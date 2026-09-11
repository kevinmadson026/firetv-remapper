#!/bin/bash

# ===== Configuration =====
IP_ADDRESS="192.168.1.12:5555"
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
    
    # Pause to allow ADB network handshake to complete
    sleep 1
    
    # Validate if the device is actually connected and authorized
    if adb devices | grep -q "${IP_ADDRESS}.*device$"; then
        return 0
    else
        return 1
    fi
}

check_health() {
    # Remote execution validating heartbeat, active PID, and valid state
    adb -s "$IP_ADDRESS" shell "
        NOW=\$(date +%s)
        ALIVE=\$(cat $REMOTE_ALIVE 2>/dev/null || echo 0)
        PID=\$(cat $REMOTE_PID 2>/dev/null || echo 0)
        STATE=\$(cat $REMOTE_STATE 2>/dev/null)
        
        [ -n \"\$ALIVE\" ] && [ \$((NOW - ALIVE)) -le $ALIVE_TIMEOUT ] && \
        [ -n \"\$PID\" ] && kill -0 \$PID 2>/dev/null && \
        case \"\$STATE\" in
            MONITORING|WAITING_DEVICE|RECOVERING_DEVICE|SLEEPING) exit 0 ;;
            *) exit 1 ;;
        esac
    " >/dev/null 2>&1
    return $?
}

is_busy() {
    adb -s "$IP_ADDRESS" shell "test -e $REMOTE_LOCK" >/dev/null 2>&1
    return $?
}

restart_service() {
    # Terminate specifically only the script PID (avoiding a global killall sh)
    adb -s "$IP_ADDRESS" shell "
        PID=\$(cat $REMOTE_PID 2>/dev/null)
        [ -n \"\$PID\" ] && kill -9 \$PID 2>/dev/null
        killall getevent 2>/dev/null
        rm -f $REMOTE_LOCK $REMOTE_STATE $REMOTE_ALIVE $REMOTE_LOOPSTART $REMOTE_PID
        nohup sh $REMOTE_SCRIPT > $REMOTE_LOG 2>&1 &
    " >/dev/null 2>&1
    return $?
}

ensure_started() {
    adb -s "$IP_ADDRESS" shell "test -f $REMOTE_SCRIPT" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[$(date +%T)] Script not found on Fire TV. Send firetv-remapper.sh to $REMOTE_SCRIPT."
        exit 1
    fi
    adb -s "$IP_ADDRESS" shell "chmod +x $REMOTE_SCRIPT && sed -i 's/\r//g' $REMOTE_SCRIPT" >/dev/null 2>&1
    restart_service
}

# ===== Script Start =====
connect_adb
if [ $? -eq 0 ]; then
    ensure_started
else
    echo "[$(date +%T)] Initially offline. Waiting for connection..."
fi

while true; do
    connect_adb
    if [ $? -ne 0 ]; then
        BAD_COUNT=0
        echo "[$(date +%T)] ADB unavailable; retrying connection in $OFFLINE_INTERVAL seconds."
        sleep $OFFLINE_INTERVAL
        continue
    fi

    check_health
    if [ $? -eq 0 ]; then
        if [ $BAD_COUNT -gt 0 ]; then
            echo "[$(date +%T)] Service recovered; temporary failure ignored."
        fi
        BAD_COUNT=0
        sleep $CHECK_INTERVAL
        continue
    fi

    BAD_COUNT=$((BAD_COUNT + 1))
    if [ $BAD_COUNT -lt $FAIL_CONFIRMATIONS ]; then
        echo "[$(date +%T)] Provisional health failure ($BAD_COUNT/$FAIL_CONFIRMATIONS); awaiting confirmation."
        sleep $CHECK_INTERVAL
        continue
    fi

    is_busy
    if [ $? -eq 0 ]; then
        echo "[$(date +%T)] Button operation in progress; recovery postponed."
        sleep $CHECK_INTERVAL
        continue
    fi

    echo "[$(date +%T)] Confirmed failure; restarting remote service only."
    restart_service
    BAD_COUNT=0
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "[$(date +%T)] Recovery completed. Restarts: $RESTART_COUNT."
    sleep $CHECK_INTERVAL
done
