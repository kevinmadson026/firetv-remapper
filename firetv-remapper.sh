#!/bin/sh

# Fire TV Key Remapper - Versão Definitiva por Colunas
PID_FILE="/sdcard/firetv-remapper.pid"

# 1. Encerra a instância anterior do script de forma segura (se existir)
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null
    fi
fi

# 2. Limpa qualquer processo 'getevent' órfão anterior
pkill getevent >/dev/null 2>&1

# 3. Grava o PID da nova instância atual
echo "$$" > "$PID_FILE"

APP_PACKAGE=${1:-"org.smarttube.stable"}
PRIME_PACKAGE="com.amazon.firebat"
NETFLIX_PACKAGE="com.netflix.ninja"
LAZER_PACKAGE="com.lazerplayer.app"

TARGET_DEVICE="/dev/input/event4"
TARGET_EVENT_SMARTTUBE="02e9"
TARGET_EVENT_NETFLIX="02e8"

echo "Monitorando eventos de tecla no dispositivo $TARGET_DEVICE para abrir: $APP_PACKAGE"

while true; do
    # O '-c 2' captura o pacote exato do pressionamento e fecha na mesma hora,
    # eliminando o atraso do buffer e pegando a tecla Home.
    line=$(getevent -t -c 2 "$TARGET_DEVICE")
    
    case "$line" in
        *" 0001 $TARGET_EVENT_SMARTTUBE 00000001"*)
                echo "Botão SmartTube pressionado! Abrindo $APP_PACKAGE..."
                sleep 1
                am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
                am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
                am force-stop "$LAZER_PACKAGE" >/dev/null 2>&1
                monkey -p "$APP_PACKAGE" -c android.intent.category.LAUNCHER 1
                ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
                echo "Botão Netflix pressionado! Abrindo Lazer Play..."
                sleep 1
                am force-stop "$PRIME_PACKAGE" >/dev/null 2>&1
                am force-stop "$NETFLIX_PACKAGE" >/dev/null 2>&1
                am force-stop "org.smarttube.stable" >/dev/null 2>&1
                monkey -p "$LAZER_PACKAGE" -c android.intent.category.LAUNCHER 1
                ;;
    esac
done