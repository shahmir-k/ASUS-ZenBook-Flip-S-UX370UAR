#!/bin/bash
# Tablet mode daemon for ASUS ZenBook Flip S
# Monitors hinge angle sensor and toggles tablet mode when lid goes past 180°
# Dependencies: xinput, onboard, iio hinge sensor
#
# Usage: tablet-mode.sh          (daemon mode - monitors hinge angle)
#        tablet-mode.sh toggle   (manual toggle)
#        tablet-mode.sh status   (print current state)

HINGE_SENSOR="/sys/bus/iio/devices/iio:device0/in_angl0_raw"
STATE_FILE="/tmp/.tablet_mode"
LOCK_FILE="/tmp/.tablet-mode.lock"
THRESHOLD_ENTER=190    # Enter tablet mode above this angle
THRESHOLD_EXIT=170     # Exit tablet mode below this angle (hysteresis)
POLL_INTERVAL=1        # seconds

KEYBOARD="AT Translated Set 2 keyboard"
TOUCHPAD="ELAN1200:00 04F3:3058 Touchpad"

enter_tablet_mode() {
    [ -f "$STATE_FILE" ] && return  # already in tablet mode

    touch "$STATE_FILE"

    # Disable keyboard and touchpad
    xinput disable "$KEYBOARD" 2>/dev/null
    xinput disable "$TOUCHPAD" 2>/dev/null

    # Launch on-screen keyboard
    if ! pgrep -x onboard >/dev/null; then
        onboard &
    fi

    # Increase UI scaling for touch
    gsettings set org.cinnamon.desktop.interface text-scaling-factor 1.3
    gsettings set org.cinnamon panels-height "['1:56']"

    notify-send "Tablet Mode" "Keyboard and touchpad disabled"
}

exit_tablet_mode() {
    [ ! -f "$STATE_FILE" ] && return  # already in laptop mode

    rm -f "$STATE_FILE"

    # Re-enable keyboard and touchpad
    xinput enable "$KEYBOARD" 2>/dev/null
    xinput enable "$TOUCHPAD" 2>/dev/null

    # Hide on-screen keyboard
    dbus-send --type=method_call --dest=org.onboard.Onboard \
        /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.Hide 2>/dev/null

    # Restore UI scaling
    gsettings set org.cinnamon.desktop.interface text-scaling-factor 1.0
    gsettings set org.cinnamon panels-height "['1:40']"

    notify-send "Laptop Mode" "Keyboard and touchpad enabled"
}

get_angle() {
    cat "$HINGE_SENSOR" 2>/dev/null || echo "0"
}

case "${1:-daemon}" in
    toggle)
        if [ -f "$STATE_FILE" ]; then
            exit_tablet_mode
        else
            enter_tablet_mode
        fi
        ;;
    status)
        angle=$(get_angle)
        if [ -f "$STATE_FILE" ]; then
            echo "tablet (hinge: ${angle}°)"
        else
            echo "laptop (hinge: ${angle}°)"
        fi
        ;;
    daemon)
        # Single instance lock
        exec 9>"$LOCK_FILE"
        flock -n 9 || { echo "Already running" >&2; exit 1; }

        # Clean state on start
        rm -f "$STATE_FILE"

        while true; do
            angle=$(get_angle)
            if [ -f "$STATE_FILE" ]; then
                # In tablet mode — exit when angle drops below threshold
                if [ "$angle" -lt "$THRESHOLD_EXIT" ] 2>/dev/null; then
                    exit_tablet_mode
                fi
            else
                # In laptop mode — enter when angle exceeds threshold
                if [ "$angle" -gt "$THRESHOLD_ENTER" ] 2>/dev/null; then
                    enter_tablet_mode
                fi
            fi
            sleep "$POLL_INTERVAL"
        done
        ;;
    *)
        echo "Usage: tablet-mode.sh [daemon|toggle|status]" >&2
        exit 1
        ;;
esac
