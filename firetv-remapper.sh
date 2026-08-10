#!/bin/sh

# Fire TV Key Remapper - Versão com Busca Dinâmica de Dispositivo
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

APP01_PACKAGE="org.smarttube.stable"
APP02_PACKAGE="com.lazerplayer.app"
APP03_PACKAGE="org.videolan.vlc"
APP04_PACKAGE="com.esaba.downloader"


PRIME_PACKAGE="com.amazon.firebat"
NETFLIX_PACKAGE="com.netflix.ninja"
DISNEY_PACKAGE="com.disney.disneyplus"
HULU_PACKAGE="com.hulu.livingroomplus"

TARGET_EVENT_PRIMEVIDEO="02e9"
TARGET_EVENT_NETFLIX="02e8"
TARGET_EVENT_DISNEY="02ea"
TARGET_EVENT_HULU="02eb"

# Função para fechar os aplicativos antes de abrir o novo
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

# Função para localizar automaticamente o evento do controle remoto da Fire TV
find_target_device() {
    # Primeira tentativa: Busca exata pelo nome exato do controle
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            name=$(getevent -i "$dev" 2>/dev/null)
            if echo "$name" | grep -qi "Amazon Fire TV Remote"; then
                echo "$dev"
                return 0
            fi
        fi
    done

    # Segunda tentativa: Busca genérica mais restrita (sem gpio-keys)
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            name=$(getevent -i "$dev" 2>/dev/null)
            if echo "$name" | grep -qiE "firetv|fire tv|amazon.*remote"; then
                echo "$dev"
                return 0
            fi
        fi
    done

    # Fallback seguro para o event4 encontrado nos seus testes
    echo "/dev/input/event4"
}

TARGET_DEVICE=$(find_target_device)
echo "Monitorando eventos de tecla no dispositivo detectado: $TARGET_DEVICE"

while true; do
    # O '-c 2' captura o pacote exato do pressionamento e fecha na mesma hora
    line=$(getevent -t -c 2 "$TARGET_DEVICE" 2>/dev/null)
    
    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
                echo "Botão Primevideo pressionado! Abrindo App $APP01_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP01_PACKAGE" -c android.intent.category.LAUNCHER 1
                ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
                echo "Botão Netflix pressionado! Abrindo App $APP02_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP02_PACKAGE" -c android.intent.category.LAUNCHER 1
                ;;
				
		*" 0001 $TARGET_EVENT_DISNEY 00000001"*)
                echo "Botão Disney+ pressionado! Abrindo App $APP03_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP03_PACKAGE" -c android.intent.category.LAUNCHER 1
				;;
				
		*" 0001 $TARGET_EVENT_HULU 00000001"*)
                echo "Botão Hulu pressionado! Abrindo App $APP04_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP04_PACKAGE" -c android.intent.category.LAUNCHER 1
				;;
    esac
done
