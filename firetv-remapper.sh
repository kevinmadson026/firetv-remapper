#!/bin/sh

# Fire TV Key Remapper
PID_FILE="/sdcard/firetv-remapper.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null
    fi
fi

pkill getevent >/dev/null 2>&1

echo "$$" > "$PID_FILE"

APP01_PACKAGE="org.smarttube.stable" # Target app for Prime Video button
APP02_PACKAGE="com.lazerplayer.app"  # Target app for Netflix button
APP03_PACKAGE="org.videolan.vlc"     # Target app for Disney+ button
APP04_PACKAGE="com.esaba.downloader" # Target app for Hulu button"


PRIME_PACKAGE="com.amazon.firebat"
NETFLIX_PACKAGE="com.netflix.ninja"
DISNEY_PACKAGE="com.disney.disneyplus"
HULU_PACKAGE="com.hulu.livingroomplus"

TARGET_EVENT_PRIMEVIDEO="02e9"
TARGET_EVENT_NETFLIX="02e8"
TARGET_EVENT_DISNEY="02ea"
TARGET_EVENT_HULU="02eb"

close_background_apps() {
    am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
    am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
	# am force-stop "$HULU_PACKAGE" >/dev/null 2>&1
	# am force-stop "$DISNEY_PACKAGE" >/dev/null 2>&1
    am force-stop "$APP01_PACKAGE" >/dev/null 2>&1
    am force-stop "$APP02_PACKAGE" >/dev/null 2>&1
    am force-stop "$APP03_PACKAGE" >/dev/null 2>&1
    am force-stop "$APP04_PACKAGE" >/dev/null 2>&1
    am force-stop "com.amazon.venezia" >/dev/null 2>&1
}

find_target_device() {
    # 1. Atalho direto: se o event5 existe e o usuário sabe que é ele, tenta validar ou assume
    if [ -e "/dev/input/event5" ]; then
        name=$(cat "/sys/class/input/event5/device/name" 2>/dev/null)
        if [ -z "$name" ]; then
            # Se a permissão bloquear a leitura do nome, mas sabemos que está no event5, retornamos ele direto
            echo "/dev/input/event5"
            return 0
        elif echo "$name" | grep -qiE "firetv|fire tv|amazon.*remote"; then
            echo "/dev/input/event5"
            return 0
        fi
    fi

    # 2. Varredura padrão caso mude no futuro
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            ev_name=$(basename "$dev")
            if [ -f "/sys/class/input/$ev_name/device/name" ]; then
                name=$(cat "/sys/class/input/$ev_name/device/name" 2>/dev/null)
                if echo "$name" | grep -qiE "firetv|fire tv|amazon.*remote"; then
                    echo "$dev"
                    return 0
                fi
            fi
        fi
    done

    # 3. Fallback final corrigido para event5 (em vez de event4)
    echo "/dev/input/event5"
}

TARGET_DEVICE=$(find_target_device)
echo "Monitoring clicks on firetv remote: $TARGET_DEVICE"

LOCK_FILE="/sdcard/firetv-remapper.lock"

while true; do
    line=$(getevent -t -c 2 "$TARGET_DEVICE" 2>/dev/null)
    
    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
                touch "$LOCK_FILE"
                echo "Primevideo button pressed! Opening app $APP01_PACKAGE..."
                sleep 1
                am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
                am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP02_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP03_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP04_PACKAGE" >/dev/null 2>&1
                monkey -p "$APP01_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
                touch "$LOCK_FILE"
                echo "Netflix button pressed! Opening app $APP02_PACKAGE..."
                sleep 1
                am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
                am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP01_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP03_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP04_PACKAGE" >/dev/null 2>&1
                monkey -p "$APP02_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
                
        *" 0001 $TARGET_EVENT_DISNEY 00000001"*)
                touch "$LOCK_FILE"
                echo "Disney+ button pressed! Opening app $APP03_PACKAGE..."
                sleep 1
                am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
                am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP01_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP02_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP04_PACKAGE" >/dev/null 2>&1
                am force-stop "com.amazon.venezia" >/dev/null 2>&1
                monkey -p "$APP03_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
                
        *" 0001 $TARGET_EVENT_HULU 00000001"*)
                touch "$LOCK_FILE"
                echo "Hulu button pressed! Opening app $APP04_PACKAGE..."
                sleep 1
                am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
                am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP01_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP02_PACKAGE" >/dev/null 2>&1
                am force-stop "$APP03_PACKAGE" >/dev/null 2>&1
                am force-stop "com.amazon.venezia" >/dev/null 2>&1
                monkey -p "$APP04_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
    esac
done
