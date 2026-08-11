#!/bin/sh

PID_FILE="/sdcard/firetv-remapper.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null
    fi
fi

pkill getevent >/dev/null 2>&1

echo "$$" > "$PID_FILE"

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

TARGET_DEVICE=$(find_target_device)
echo "Monitoring key events on detected device: $TARGET_DEVICE"

LOCK_FILE="/sdcard/firetv-remapper.lock"

while true; do
    # 1. Checa se a variável está vazia ou se o arquivo do dispositivo deixou de existir
    if [ -z "$TARGET_DEVICE" ] || [ ! -e "$TARGET_DEVICE" ]; then
        TARGET_DEVICE=$(find_target_device)
        
        # Se o controle ainda não reconectou, aguarda 2 segundos e tenta de novo (evita alto uso de CPU)
        if [ -z "$TARGET_DEVICE" ]; then
            sleep 2
            continue
        fi
        echo "Controle reconectado. Monitorando: $TARGET_DEVICE"
    fi

    # 2. Tenta capturar os eventos
    line=$(getevent -t -c 2 "$TARGET_DEVICE" 2>/dev/null)
    
    # 3. Se o getevent falhar ou retornar vazio (ex: TV dormiu e cortou a conexão durante a leitura)
    if [ -z "$line" ]; then
        sleep 1
        TARGET_DEVICE="" # Zera a variável para forçar a busca (passo 1) no próximo ciclo
        continue
    fi
    
    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
                touch "$LOCK_FILE"
                echo "Primevideo button pressed! Opening App $APP01_PACKAGE..."
                sleep 1
                closeapps
                monkey -p "$APP01_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
                touch "$LOCK_FILE"
                echo "Netflix button pressed! Opening App $APP02_PACKAGE..."
                sleep 1
                closeapps
                monkey -p "$APP02_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
        *" 0001 $TARGET_EVENT_DISNEY 00000001"*)
                touch "$LOCK_FILE"
                echo "Disney+ button pressed! Opening App $APP03_PACKAGE..."
                sleep 1
                closeapps
                monkey -p "$APP03_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
        *" 0001 $TARGET_EVENT_HULU 00000001"*)
                touch "$LOCK_FILE"
                echo "Hulu button pressed! Opening App $APP04_PACKAGE..."
                sleep 1
                closeapps
                monkey -p "$APP04_PACKAGE" -c android.intent.category.LAUNCHER 1
                rm -f "$LOCK_FILE"
                ;;
    esac
done