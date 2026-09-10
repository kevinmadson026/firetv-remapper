#!/system/bin/sh

# Fire TV Remote Button Remapper
# Versão com timeout de getevent e marcador de progresso para o watchdog.

BASE_DIR="/sdcard"
PID_FILE="$BASE_DIR/firetv-remapper.pid"
HEARTBEAT_FILE="$BASE_DIR/firetv-remapper.heartbeat"
STATE_FILE="$BASE_DIR/firetv-remapper.state"
LOCK_FILE="$BASE_DIR/firetv-remapper.lock"
ALIVE_FILE="$BASE_DIR/firetv-remapper.alive"
LOOPSTART_FILE="$BASE_DIR/firetv-remapper.loopstart"
EVENT_FILE="$BASE_DIR/firetv-remapper.event"
LOG_TAG="firetv-remapper"
EVENT_TIMEOUT=10

APP01_PACKAGE="org.smarttube.stable"
APP02_PACKAGE="com.lazerplayer.app"
APP03_PACKAGE="com.instantbits.cast.receiver"
APP04_PACKAGE="de.belu.appstarter"

PRIME_PACKAGE="com.amazon.firebat"
NETFLIX_PACKAGE="com.netflix.ninja"
HULU_PACKAGE="com.hulu.plus"
DISNEY_PACKAGE="com.disney.disneyplus"

TARGET_EVENT_PRIMEVIDEO="02e9"
TARGET_EVENT_NETFLIX="02e8"
TARGET_EVENT_DISNEY="02ea"
TARGET_EVENT_HULU="02eb"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LOG_TAG] $*"
}

write_state() {
    echo "$1" > "$STATE_FILE"
}

stop_all_getevent() {
    killall getevent >/dev/null 2>&1
    sleep 1
    killall getevent >/dev/null 2>&1
}

stop_previous_instance() {
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)

    for REMAPPER_PID in $(ps 2>/dev/null | awk '$0 ~ /[f]iretv-remapper\.sh/ {print $1}'); do
        if [ "$REMAPPER_PID" != "$$" ]; then
            log "Terminando remapper anterior, PID $REMAPPER_PID."
            kill "$REMAPPER_PID" 2>/dev/null
        fi
    done

    if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ]; then
        kill "$OLD_PID" 2>/dev/null
    fi

    sleep 1

    for REMAPPER_PID in $(ps 2>/dev/null | awk '$0 ~ /[f]iretv-remapper\.sh/ {print $1}'); do
        if [ "$REMAPPER_PID" != "$$" ]; then
            kill -9 "$REMAPPER_PID" 2>/dev/null
        fi
    done

    stop_all_getevent
    rm -f "$ALIVE_FILE" "$HEARTBEAT_FILE" "$LOOPSTART_FILE" "$EVENT_FILE"
}

stop_previous_instance
echo "$$" > "$PID_FILE"
write_state "STARTING"

pulse_worker() {
    while true; do
        date +%s > "$ALIVE_FILE"
        sleep 1
done
}

pulse_worker &
PULSE_PID=$!

cleanup() {
    CURRENT_PID=$(cat "$PID_FILE" 2>/dev/null)

    if [ "$CURRENT_PID" = "$$" ]; then
        [ -n "$EVENT_PID" ] && kill "$EVENT_PID" 2>/dev/null
        write_state "STOPPED"
        rm -f "$ALIVE_FILE" "$HEARTBEAT_FILE" "$LOOPSTART_FILE" "$EVENT_FILE" "$PID_FILE" "$LOCK_FILE"
    fi

    exit 0
}

trap cleanup INT TERM HUP EXIT

closeapps() {
    am force-stop "$APP01_PACKAGE" >/dev/null 2>&1
    am force-stop "$APP02_PACKAGE" >/dev/null 2>&1
    am force-stop "$APP03_PACKAGE" >/dev/null 2>&1
    am force-stop "$APP04_PACKAGE" >/dev/null 2>&1
    am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
    am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
    am force-stop "$HULU_PACKAGE" >/dev/null 2>&1
    am force-stop "$DISNEY_PACKAGE" >/dev/null 2>&1
    am force-stop "com.amazon.venezia" >/dev/null 2>&1
}

find_target_device() {
    getevent -i 2>/dev/null | awk '
        /add device/ { d = $4 }
        /bus:/ { b = $2 }
        /name:/ {
            if ($0 ~ /"Amazon Fire TV Remote"/ && b == "0005") {
                print d
                exit
            }
        }
    '
}

launch_app() {
    PACKAGE="$1"
    sleep 1
    closeapps
    monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

# Lê somente um evento e impede que getevent fique preso indefinidamente.
# O loopstart permite ao run.bat detectar um getevent travado.
read_event() {
    rm -f "$EVENT_FILE"
    date +%s > "$LOOPSTART_FILE"

    getevent -t -c 1 "$TARGET_DEVICE" > "$EVENT_FILE" 2>/dev/null &
    EVENT_PID=$!
    WAITED=0

    while kill -0 "$EVENT_PID" 2>/dev/null; do
        date +%s > "$ALIVE_FILE"
        date +%s > "$HEARTBEAT_FILE"
        sleep 1
        WAITED=$((WAITED + 1))

        if [ "$WAITED" -ge "$EVENT_TIMEOUT" ]; then
            log "Timeout aguardando evento; encerrando getevent PID $EVENT_PID."
            kill "$EVENT_PID" 2>/dev/null
            sleep 1
            kill -9 "$EVENT_PID" 2>/dev/null
            wait "$EVENT_PID" 2>/dev/null
            EVENT_PID=""
            rm -f "$LOOPSTART_FILE" "$EVENT_FILE"
            return 1
        fi
    done

    wait "$EVENT_PID" 2>/dev/null
    EVENT_PID=""
    rm -f "$LOOPSTART_FILE"
    return 0
}

TARGET_DEVICE=""
write_state "WAITING_DEVICE"
date +%s > "$ALIVE_FILE"
date +%s > "$HEARTBEAT_FILE"
log "Serviço iniciado; aguardando o controle remoto."

while true; do
    date +%s > "$ALIVE_FILE"
    date +%s > "$HEARTBEAT_FILE"

    if [ -z "$TARGET_DEVICE" ] || [ ! -e "$TARGET_DEVICE" ]; then
        write_state "WAITING_DEVICE"
        TARGET_DEVICE=$(find_target_device)

        if [ -z "$TARGET_DEVICE" ]; then
            sleep 2
            continue
        fi

        log "Controle remoto detectado em $TARGET_DEVICE."
    fi

    write_state "MONITORING"

    if ! read_event; then
        TARGET_DEVICE=""
        write_state "RECOVERING_DEVICE"
        sleep 1
        continue
    fi

    line=$(cat "$EVENT_FILE" 2>/dev/null)
    rm -f "$EVENT_FILE"

    if [ -z "$line" ]; then
        TARGET_DEVICE=""
        write_state "RECOVERING_DEVICE"
        continue
    fi

    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_PRIMEVIDEO"
            log "Botão Prime Video detectado; abrindo $APP01_PACKAGE."
            launch_app "$APP01_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_NETFLIX"
            log "Botão Netflix detectado; abrindo $APP02_PACKAGE."
            launch_app "$APP02_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_DISNEY 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_DISNEY"
            log "Botão Disney+ detectado; abrindo $APP03_PACKAGE."
            launch_app "$APP03_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_HULU 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_HULU"
            log "Botão Hulu detectado; abrindo $APP04_PACKAGE."
            launch_app "$APP04_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
    esac
done
