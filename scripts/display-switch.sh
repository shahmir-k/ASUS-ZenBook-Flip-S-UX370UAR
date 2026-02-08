#!/bin/bash
# Display switch — cycles through modes like Windows Win+P
# Usage: display-switch.sh
# Modes: internal → mirror → extend → external → internal ...

STATE_FILE="/tmp/.display_mode"
OSD="gdbus call --session --dest org.Cinnamon --object-path /org/Cinnamon --method org.Cinnamon.ShowOSD"
INTERNAL="eDP-1"

# Find first connected external display
EXTERNAL=$(xrandr --query | grep " connected" | grep -v "$INTERNAL" | head -1 | awk '{print $1}')

if [ -z "$EXTERNAL" ]; then
    $OSD "{'icon': <'video-display-symbolic'>, 'monitor': <int32 -1>}" > /dev/null 2>&1
    notify-send "Display Switch" "No external display connected"
    exit 0
fi

# Get external display's preferred resolution
EXT_RES=$(xrandr --query | sed -n "/$EXTERNAL connected/,/^[^ ]/p" | grep -oP '\d+x\d+' | head -1)

# Read current mode
current=$(cat "$STATE_FILE" 2>/dev/null || echo "internal")

case "$current" in
    internal)
        # → Mirror
        xrandr --output "$EXTERNAL" --auto --same-as "$INTERNAL"
        echo "mirror" > "$STATE_FILE"
        notify-send "Display Switch" "Mirror ($INTERNAL + $EXTERNAL)"
        ;;
    mirror)
        # → Extend (external to the right)
        xrandr --output "$EXTERNAL" --auto --right-of "$INTERNAL"
        echo "extend" > "$STATE_FILE"
        notify-send "Display Switch" "Extend ($EXTERNAL right of $INTERNAL)"
        ;;
    extend)
        # → External only
        xrandr --output "$INTERNAL" --off --output "$EXTERNAL" --auto --primary
        echo "external" > "$STATE_FILE"
        notify-send "Display Switch" "External only ($EXTERNAL)"
        ;;
    external)
        # → Internal only
        xrandr --output "$EXTERNAL" --off --output "$INTERNAL" --auto --primary
        echo "internal" > "$STATE_FILE"
        notify-send "Display Switch" "Internal only ($INTERNAL)"
        ;;
esac
