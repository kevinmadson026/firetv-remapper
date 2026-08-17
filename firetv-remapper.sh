#!/system/bin/sh

# Fire TV Remote Button Remapper
# Apenas uma instância deste script pode permanecer ativa.

BASE_DIR="/sdcard"
PID_FILE="$BASE_DIR/firetv-remapper.pid"
HEARTBEAT_FILE="$BASE_DIR/firetv-remapper.heartbeat"
STATE_FILE="$BASE_DIR/firetv-remapper.state"
LOCK_FILE="$BASE_DIR/firetv-remapper.lock"
INSTANCE_LOCK_DIR="$BASE_DIR/firetv-remapper.instance.lock"
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

# mkdir e atomico no Android/Linux: somente uma instancia consegue criar o diretorio.
# Diferentemente do comportamento anterior, uma nova execucao nao mata a instancia ativa.
if ! mkdir "$INSTANCE_LOCK_DIR" 2>/dev/null; then
    OLD_PID=$(cat "$INSTANCE_LOCK_DIR/pid" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        log "Instancia ja ativa (PID $OLD_PID); esta execucao sera encerrada."
        exit 0
    fi

    # Se o PID ainda nao foi gravado, o processo vencedor pode estar no intervalo
    # entre mkdir e echo. Nao remova o lock nesse caso, para evitar uma corrida.
    if [ -z "$OLD_PID" ]; then
        log "Lock ocupado sem PID; esta execucao sera encerrada."
        exit 0
    fi

    # Lock com PID morto: recupera somente lock comprovadamente obsoleto.
    log "Removendo lock obsoleto (PID $OLD_PID)."
    rm -rf "$INSTANCE_LOCK_DIR"
    if ! mkdir "$INSTANCE_LOCK_DIR" 2>/dev/null; then
        log "Outra instancia assumiu o lock durante a recuperacao; encerrando."
        exit 0
    fi
fi

echo "$$" > "$INSTANCE_LOCK_DIR/pid"
echo "$$" > "$PID_FILE"
write_state "STARTING"

cleanup() {
    write_state "STOPPED"
    rm -f "$HEARTBEAT_FILE" "$PID_FILE" "$LOCK_FILE"
    rm -rf "$INSTANCE_LOCK_DIR"
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
log "Servico iniciado; aguardando o controle remoto."

while true; do
    if [ -z "$TARGET_DEVICE" ] || [ ! -e "$TARGET_DEVICE" ]; then
        write_state "WAITING_DEVICE"
        date +%s > "$HEARTBEAT_FILE"
        TARGET_DEVICE=$(find_target_device)
        if [ -z "$TARGET_DEVICE" ]; then
            sleep 2
            continue
        fi
        log "Controle detectado em $TARGET_DEVICE."
    fi

    write_state "MONITORING"
    date +%s > "$HEARTBEAT_FILE"
    # Esta chamada e sequencial; com uma unica instancia do script, existe no
    # maximo um getevent de monitoramento criado por este servico.
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
            log "Botao Prime Video detectado; abrindo $APP01_PACKAGE."
            launch_app "$APP01_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_NETFLIX"
            log "Botao Netflix detectado; abrindo $APP02_PACKAGE."
            launch_app "$APP02_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_DISNEY 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_DISNEY"
            log "Botao Disney+ detectado; abrindo $APP03_PACKAGE."
            launch_app "$APP03_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
        *" 0001 $TARGET_EVENT_HULU 00000001"*)
            touch "$LOCK_FILE"
            write_state "HANDLING_HULU"
            log "Botao Hulu detectado; abrindo $APP04_PACKAGE."
            launch_app "$APP04_PACKAGE"
            rm -f "$LOCK_FILE"
            ;;
    esac
done
