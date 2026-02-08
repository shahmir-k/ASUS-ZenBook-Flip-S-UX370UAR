#!/bin/bash
# F8 display control
# Short press (<2s): cycle display modes (internal → mirror → extend → external)
# Long press (>2s): open wireless display casting (GNOME Network Displays)

KEYBOARD=$(xinput list | grep -i "AT Translated" | grep -oP 'id=\K\d+')

# Monitor for keycode 74 (F8) release, timeout after 2 seconds
if timeout 2 bash -c "xinput test $KEYBOARD 2>/dev/null | grep -m1 'key release  74'" > /dev/null 2>&1; then
    # Released within 2 seconds — short press → cycle display mode
    /home/shahmir/.local/bin/display-switch.sh
else
    # Held for 2+ seconds — long press → open casting menu
    gnome-network-displays &
fi
