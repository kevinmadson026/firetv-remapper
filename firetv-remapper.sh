#!/system/bin/sh

# Fire TV Remote Button Remapper
# Versão com getevent contínuo para evitar a janela entre dois eventos.

BASE_DIR="/sdcard"
PID_FILE="$BASE_DIR/firetv-remapper.pid"
STATE_FILE="$BASE_DIR/firetv-remapper.state"
LOCK_FILE="$BASE_DIR/firetv-remapper.lock"
ALIVE_FILE="$BASE_DIR/firetv-remapper.alive"
EVENT_FIFO="$BASE_DIR/firetv-remapper.events"
LOG_TAG="firetv-remapper"

APP01_PACKAGE="com.google.android.youtube.tv" # Prime Video button
APP02_PACKAGE="org.xbmc.kodi"                  # Netflix button
APP03_PACKAGE="org.videolan.vlc"               # Disney+ button
APP04_PACKAGE="com.esaba.downloader"           # Hulu button

PRIME_PACKAGE="com.amazon.firebat"
NETFLIX_PACKAGE="com.netflix.ninja"
HULU_PACKAGE="com.hulu.plus"
DISNEY_PACKAGE="com.disney.disneyplus"
VENEZIA_PACKAGE="com.amazon.venezia"

TARGET_EVENT_PRIMEVIDEO="02e9"
TARGET_EVENT_NETFLIX="02e8"
TARGET_EVENT_DISNEY="02ea"
TARGET_EVENT_HULU="02eb"

TARGET_DEVICE=""
EVENT_PID=""
PULSE_PID=""

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

    for REMAPPER_PID in $(ps 2>/dev/null | awk '$0 ~ /[f]iretv-remapper(-fixed)?\.sh/ {print $1}'); do
        if [ "$REMAPPER_PID" != "$$" ]; then
            log "Terminando remapper anterior, PID $REMAPPER_PID."
            kill "$REMAPPER_PID" 2>/dev/null
        fi
    done

    if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ]; then
        kill "$OLD_PID" 2>/dev/null
    fi

    sleep 1

    for REMAPPER_PID in $(ps 2>/dev/null | awk '$0 ~ /[f]iretv-remapper(-fixed)?\.sh/ {print $1}'); do
        if [ "$REMAPPER_PID" != "$$" ]; then
            kill -9 "$REMAPPER_PID" 2>/dev/null
        fi
    done

    stop_all_getevent
    rm -f "$EVENT_FIFO" "$ALIVE_FILE" "$STATE_FILE" "$LOCK_FILE" "$PID_FILE"
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
        [ -n "$PULSE_PID" ] && kill "$PULSE_PID" 2>/dev/null
        exec 3<&- 2>/dev/null
        write_state "STOPPED"
        rm -f "$EVENT_FIFO" "$ALIVE_FILE" "$STATE_FILE" "$LOCK_FILE" "$PID_FILE"
    fi

    exit 0
}

trap cleanup INT TERM HUP EXIT

# Fecha somente um aplicativo conhecido que esteja em primeiro plano.
# Não força parada de todos os pacotes, evitando uma pausa longa e desnecessária.
close_current_app() {
    CURRENT_PACKAGE=$(dumpsys window windows 2>/dev/null | \
        sed -n 's/.* u0 \([^ /]*\)\/[^ ]*.*/\1/p' | head -n 1)

    if [ -z "$CURRENT_PACKAGE" ]; then
        CURRENT_PACKAGE=$(dumpsys activity activities 2>/dev/null | \
            sed -n 's/.*mResumedActivity:.* u0 \([^ /]*\)\/[^ ]*.*/\1/p' | head -n 1)
    fi

    case "$CURRENT_PACKAGE" in
        "$APP01_PACKAGE"|"$APP02_PACKAGE"|"$APP03_PACKAGE"|"$APP04_PACKAGE"|\
        "$PRIME_PACKAGE"|"$NETFLIX_PACKAGE"|"$HULU_PACKAGE"|"$DISNEY_PACKAGE"|\
        "$VENEZIA_PACKAGE")
            am force-stop "$CURRENT_PACKAGE" >/dev/null 2>&1
            ;;
    esac
}

launch_app() {
    PACKAGE="$1"
    close_current_app
    monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
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

# Mantém um único getevent aberto durante toda a execução.
# Enquanto launch_app roda, os eventos permanecem no buffer do FIFO;
# assim não existe a lacuna causada por destruir e recriar getevent a cada clique.
monitor_events() {
    rm -f "$EVENT_FIFO"
    mkfifo "$EVENT_FIFO" 2>/dev/null || {
        log "Não foi possível criar o FIFO $EVENT_FIFO."
        return 1
    }

    getevent -t "$TARGET_DEVICE" > "$EVENT_FIFO" 2>/dev/null &
    EVENT_PID=$!

    # A abertura bloqueia até o getevent abrir o FIFO para escrita.
    exec 3< "$EVENT_FIFO"
    write_state "MONITORING"

    while IFS= read -r line <&3; do
        date +%s > "$ALIVE_FILE"

        case "$line" in
            *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
                touch "$LOCK_FILE"
                write_state "HANDLING_PRIMEVIDEO"
                log "Botão Prime Video detectado; abrindo $APP01_PACKAGE."
                launch_app "$APP01_PACKAGE"
                rm -f "$LOCK_FILE"
                write_state "MONITORING"
                ;;
            *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
                touch "$LOCK_FILE"
                write_state "HANDLING_NETFLIX"
                log "Botão Netflix detectado; abrindo $APP02_PACKAGE."
                launch_app "$APP02_PACKAGE"
                rm -f "$LOCK_FILE"
                write_state "MONITORING"
                ;;
            *" 0001 $TARGET_EVENT_DISNEY 00000001"*)
                touch "$LOCK_FILE"
                write_state "HANDLING_DISNEY"
                log "Botão Disney+ detectado; abrindo $APP03_PACKAGE."
                launch_app "$APP03_PACKAGE"
                rm -f "$LOCK_FILE"
                write_state "MONITORING"
                ;;
            *" 0001 $TARGET_EVENT_HULU 00000001"*)
                touch "$LOCK_FILE"
                write_state "HANDLING_HULU"
                log "Botão Hulu detectado; abrindo $APP04_PACKAGE."
                launch_app "$APP04_PACKAGE"
                rm -f "$LOCK_FILE"
                write_state "MONITORING"
                ;;
        esac
    done

    exec 3<&-
    kill "$EVENT_PID" 2>/dev/null
    wait "$EVENT_PID" 2>/dev/null
    EVENT_PID=""
    rm -f "$EVENT_FIFO" "$LOCK_FILE"
    return 1
}

write_state "WAITING_DEVICE"
date +%s > "$ALIVE_FILE"
log "Serviço iniciado; aguardando o controle remoto."

while true; do
    date +%s > "$ALIVE_FILE"

    if [ -z "$TARGET_DEVICE" ] || [ ! -e "$TARGET_DEVICE" ]; then
        write_state "WAITING_DEVICE"
        TARGET_DEVICE=$(find_target_device)

        if [ -z "$TARGET_DEVICE" ]; then
            sleep 2
            continue
        fi

        log "Controle remoto detectado em $TARGET_DEVICE."
    fi

    monitor_events
    TARGET_DEVICE=""
    write_state "RECOVERING_DEVICE"
    sleep 1
done
