#!/system/bin/sh

# Fire TV Remote Button Remapper
# A new execution terminates the previous instance before taking over the service.

BASE_DIR="/sdcard"
PID_FILE="$BASE_DIR/firetv-remapper.pid"
HEARTBEAT_FILE="$BASE_DIR/firetv-remapper.heartbeat"
STATE_FILE="$BASE_DIR/firetv-remapper.state"
LOCK_FILE="$BASE_DIR/firetv-remapper.lock"
LOG_TAG="firetv-remapper"

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
    # killall works on Fire OS and terminates all previous getevent processes.
    killall getevent >/dev/null 2>&1
    sleep 1
    killall getevent >/dev/null 2>&1
}

stop_previous_instance() {
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)

    # Terminates all old copies of the remapper itself, not only the one in the PID file.
    for REMAPPER_PID in $(ps 2>/dev/null | awk '$0 ~ /[f]iretv-remapper\.sh/ {print $1}'); do
        if [ "$REMAPPER_PID" != "$$" ]; then
            log "Terminating previous remapper (PID $REMAPPER_PID)."
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

    # Only after stopping all copies does it remove all old getevent processes.
    stop_all_getevent
}

stop_previous_instance
echo "$$" > "$PID_FILE"
write_state "STARTING"

cleanup() {
    CURRENT_PID=$(cat "$PID_FILE" 2>/dev/null)
    # The old instance must not delete the files that already belong to the new one.
    if [ "$CURRENT_PID" = "$$" ]; then
        write_state "STOPPED"
        rm -f "$HEARTBEAT_FILE" "$PID_FILE" "$LOCK_FILE"
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

TARGET_DEVICE=""
write_state "WAITING_DEVICE"
log "Service started; waiting for the remote control."

while true; do
    if [ -z "$TARGET_DEVICE" ] || [ ! -e "$TARGET_DEVICE" ]; then
        write_state "WAITING_DEVICE"
        date +%s > "$HEARTBEAT_FILE"
        TARGET_DEVICE=$(find_target_device)
        if [ -z "$TARGET_DEVICE" ]; then
            sleep 2
            continue
        fi
        log "Remote detected at $TARGET_DEVICE."
    fi

    write_state "MONITORING"
    date +%s > "$HEARTBEAT_FILE"
    # This call is sequential; with a single instance of the script, at most one
    # monitoring getevent is created by this service.
    line=$(getevent -t -c 1 "$TARGET_DEVICE" 2>/dev/null)
    if [ -z "$line" ]; then
        TARGET_DEVICE=""
        write_state "RECOVERING_DEVICE"
        sleep 1
        continue
    fi

    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_PRIMEVIDEO"
            log "Prime Video button detected; opening $APP01_PACKAGE."
            launch_app "$APP01_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_NETFLIX"
            log "Netflix button detected; opening $APP02_PACKAGE."
            launch_app "$APP02_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_DISNEY 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_DISNEY"
            log "Disney+ button detected; opening $APP03_PACKAGE."
            launch_app "$APP03_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_HULU 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_HULU"
            log "Hulu button detected; opening $APP04_PACKAGE."
            launch_app "$APP04_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
    esac
done
