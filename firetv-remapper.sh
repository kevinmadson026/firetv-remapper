#!/system/bin/sh

# Fire TV Remote Button Remapper (corrigido)
#
# Problema anterior: um unico clique fisico gerava 3 linhas de log.
# O getevent retorna 3 linhas por clique (down 00000001, repeat 00000002,
# release 00000000), mas a firmware do controle tambem pode retransmitir
# o mesmo evento varias vezes. A versao anterior registava cada linha
# "down" separadamente, porque:
#   1) press_is_locked() criava o lock SO apos processar o primeiro evento,
#      mas launch_app() demora ~1s (sleep + closeapps + monkey). Qualquer
#      evento "down" duplicado que chegasse ANTES de register_press()
#      passava pelo debounce e era logado de novo.
#   2) DEBOUNCE_SECS=3 so comecava a contar depois de register_press(),
#      ou seja, a janela nao protegia o momento da propria chegada.
#   3) O lock era apagado ao final de launch_app(); se o repetido chegasse
#      logo depois, press_is_locked() ja retornava 1 (falso = desbloqueado).
#
# Correcao aplicada:
#   - Lock imediato (touch do LOCK_FILE) logo na primeira deteccao de um
#     evento "down" valido, ANTES de qualquer processamento, e mantido por
#     todo o DEBOUNCE_SECS, mesmo que launch_app ainda nao tenha terminado.
#   - Debounce agressivo e deterministico: ignora qualquer outro evento
#     "down" dentro da janela de silencio, independentemente do estado do
#     lock fisico.
#   - A linha de log so e gravada UMA vez por clique (antes de launch_app).

BASE_DIR="/sdcard"
PID_FILE="$BASE_DIR/firetv-remapper.pid"
HEARTBEAT_FILE="$BASE_DIR/firetv-remapper.heartbeat"
STATE_FILE="$BASE_DIR/firetv-remapper.state"
LOCK_FILE="$BASE_DIR/firetv-remapper.lock"
LAST_PRESS_FILE="$BASE_DIR/firetv-remapper.lastpress"
LOG_TAG="firetv-remapper"

DEBOUNCE_SECS=3

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
    # killall works on Fire OS and terminates all previous getevent instances.
    killall getevent >/dev/null 2>&1
    sleep 1
    killall getevent >/dev/null 2>&1
}

stop_previous_instance() {
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)

    # Terminates all old copies of the remapper itself, not just the one in the PID file.
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

    # Only after stopping all copies, remove all old getevent instances.
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
        rm -f "$HEARTBEAT_FILE" "$PID_FILE" "$LOCK_FILE" "$LAST_PRESS_FILE"
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

# Returns 0 (true) if a press is locked or still inside the debounce window.
# CORRECAO: o lock (LOCK_FILE) e criado Imediatamente na chegada do primeiro
# evento valido, e a janela de debounce conta desde o ultimo evento "down"
# registrado. Assim, repeticoes do firmware que chegam em qualquer momento
# dentro de DEBOUNCE_SECS sao sempre ignoradas.
press_is_locked() {
    if [ -e "$LOCK_FILE" ]; then
        return 0
    fi
    NOW=$(date +%s)
    LAST=$(cat "$LAST_PRESS_FILE" 2>/dev/null)
    if [ -n "$LAST" ] && [ $((NOW - LAST)) -lt "$DEBOUNCE_SECS" ]; then
        return 0
    fi
    return 1
}

register_press() {
    # Lock imediato: protege contra repetidos que cheguem antes/durante
    # o processamento, antes de qualquer outra operacao.
    touch "$LOCK_FILE"
    date +%s > "$LAST_PRESS_FILE"
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
    # getevent -c 1 captura um unico evento por vez.
    line=$(getevent -t -c 1 "$TARGET_DEVICE" 2>/dev/null)
    if [ -z "$line" ]; then
        TARGET_DEVICE=""
        write_state "RECOVERING_DEVICE"
        sleep 1
        continue
    fi

    # CORRECAO PRINCIPAL: o lock e o registro de tempo sao feitos Imediatamente
    # na chegada do primeiro evento "down" valido, ANTES de verificar qual
    # botao foi pressionado. Mesmo que o firmware retransmita o mesmo evento
    # varias vezes dentro da mesma janela, apenas o primeiro sera registrado.
    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"* | \
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"* | \
        *" 0001 $TARGET_EVENT_DISNEY 00000001"* | \
        *" 0001 $TARGET_EVENT_HULU 00000001"*)
            if press_is_locked; then
                # Evento duplicado/dentro da janela de debounce; ignorar.
                continue
            fi
            # Lock imediato: marca o clique como "em processamento".
            register_press
            ;;
    esac

    # Processamento: apenas se nao estava bloqueado (primeiro evento da janela).
    HANDLED=0
    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
            write_state "HANDLING_PRIMEVIDEO"
            log "Prime Video button detected; opening $APP01_PACKAGE."
            launch_app "$APP01_PACKAGE"
            HANDLED=1
            ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
            write_state "HANDLING_NETFLIX"
            log "Netflix button detected; opening $APP02_PACKAGE."
            launch_app "$APP02_PACKAGE"
            HANDLED=1
            ;;
        *" 0001 $TARGET_EVENT_DISNEY 00000001"*)
            write_state "HANDLING_DISNEY"
            log "Disney+ button detected; opening $APP03_PACKAGE."
            launch_app "$APP03_PACKAGE"
            HANDLED=1
            ;;
        *" 0001 $TARGET_EVENT_HULU 00000001"*)
            write_state "HANDLING_HULU"
            log "Hulu button detected; opening $APP04_PACKAGE."
            launch_app "$APP04_PACKAGE"
            HANDLED=1
            ;;
    esac

    # Remove o lock APENAS quando este evento foi efetivamente processado.
    # Se o evento caiu no debounce (duplicado), o lock permanece valido
    # para os demais repetidos que ainda possam chegar.
    if [ "$HANDLED" = "1" ]; then
        rm -f "$LOCK_FILE"
    fi
done
