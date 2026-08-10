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
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            name=$(getevent -i "$dev" 2>/dev/null)
            if echo "$name" | grep -qi "Amazon Fire TV Remote"; then
                echo "$dev"
                return 0
            fi
        fi
    done

    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            name=$(getevent -i "$dev" 2>/dev/null)
            if echo "$name" | grep -qiE "firetv|fire tv|amazon.*remote"; then
                echo "$dev"
                return 0
            fi
        fi
    done

    echo "/dev/input/event4"
}

TARGET_DEVICE=$(find_target_device)
echo "Monitoring clicks on firetv remote: $TARGET_DEVICE"

while true; do
    line=$(getevent -t -c 2 "$TARGET_DEVICE" 2>/dev/null)
    
    case "$line" in
        *" 0001 $TARGET_EVENT_PRIMEVIDEO 00000001"*)
                echo "Primevideo Button pressed! Opening App $APP01_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP01_PACKAGE" -c android.intent.category.LAUNCHER 1
                ;;
        *" 0001 $TARGET_EVENT_NETFLIX 00000001"*)
                echo "Netflix Button pressed! Opening App $APP02_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP02_PACKAGE" -c android.intent.category.LAUNCHER 1
                ;;
				
		*" 0001 $TARGET_EVENT_DISNEY 00000001"*)
                echo "Disney+ Button pressed! Opening App  $APP03_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP03_PACKAGE" -c android.intent.category.LAUNCHER 1
				;;
				
		*" 0001 $TARGET_EVENT_HULU 00000001"*)
                echo "Hulu Button pressed! Opening App $APP04_PACKAGE..."
                sleep 1
				close_background_apps
                monkey -p "$APP04_PACKAGE" -c android.intent.category.LAUNCHER 1
				;;
    esac
done
