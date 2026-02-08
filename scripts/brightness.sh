#!/bin/bash
# Unified brightness control with mute-aware behavior and OSD
# Usage: brightness.sh up|down|toggle

LOCK_FILE="/tmp/.brightness.lock"
SAVE_FILE="/tmp/.brightness_saved"

# Non-blocking lock — drop event if another instance is running
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

dbus_screen() {
    gdbus call --session \
        --dest org.cinnamon.SettingsDaemon.Power \
        --object-path /org/cinnamon/SettingsDaemon/Power \
        --method "org.cinnamon.SettingsDaemon.Power.Screen.$1" \
        "${@:2}" 2>/dev/null
}

show_osd() {
    gdbus call --session \
        --dest org.Cinnamon \
        --object-path /org/Cinnamon \
        --method org.Cinnamon.ShowOSD \
        "{'icon': <'display-brightness-symbolic'>, 'level': <int32 $1>}" \
        > /dev/null 2>&1
}

get_level() {
    local result
    result=$(dbus_screen GetPercentage) || { echo "brightness.sh: csd-power unreachable" >&2; exit 1; }
    echo "$result" | sed 's/.*uint32 \([0-9]*\).*/\1/'
}

unmute_if_needed() {
    if [ -f "$SAVE_FILE" ]; then
        local saved
        saved=$(cat "$SAVE_FILE")
        dbus_screen SetPercentage "$saved" > /dev/null
        rm "$SAVE_FILE"
    fi
}

case "$1" in
    up)
        unmute_if_needed
        level=$(get_level)
        if [ "$level" -ge 100 ]; then
            show_osd 100
            exit 0
        fi
        dbus_screen StepUp > /dev/null
        show_osd "$(get_level)"
        ;;
    down)
        unmute_if_needed
        level=$(get_level)
        if [ "$level" -le 0 ]; then
            show_osd 0
            exit 0
        fi
        dbus_screen StepDown > /dev/null
        show_osd "$(get_level)"
        ;;
    toggle)
        if [ -f "$SAVE_FILE" ]; then
            saved=$(cat "$SAVE_FILE")
            dbus_screen SetPercentage "$saved" > /dev/null
            rm "$SAVE_FILE"
            show_osd "$saved"
        else
            current=$(get_level)
            echo "$current" > "$SAVE_FILE"
            dbus_screen SetPercentage 0 > /dev/null
            show_osd 0
        fi
        ;;
    *)
        echo "Usage: brightness.sh up|down|toggle" >&2
        exit 1
        ;;
esac
