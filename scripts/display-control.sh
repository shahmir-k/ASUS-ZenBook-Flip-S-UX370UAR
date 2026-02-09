#!/bin/bash
# F8 display control
# Short press (<2s): cycle display modes (internal → mirror → extend → external)
# Long press (>2s): open wireless display casting (GNOME Network Displays)

LOCK_FILE="/tmp/.display-control.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

KEYBOARD=$(xinput list | grep -i "AT Translated" | grep -oP 'id=\K\d+')
start=$(date +%s)

# Poll keyboard state every 100ms — check if keycode 74 (F8) is still held
while xinput query-state "$KEYBOARD" 2>/dev/null | grep -q "key\[74\]=down"; do
    now=$(date +%s)
    if [ $((now - start)) -ge 2 ]; then
        gnome-network-displays &
        exit 0
    fi
    sleep 0.1
done

# Key was released before 2 seconds — short press
/home/shahmir/.local/bin/display-switch.sh
