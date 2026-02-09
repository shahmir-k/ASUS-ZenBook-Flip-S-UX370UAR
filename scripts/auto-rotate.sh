#!/bin/bash
# Auto-rotation script for ASUS ZenBook Flip S
# Monitors iio-sensor-proxy orientation and rotates display + touch input
# Dependencies: iio-sensor-proxy, xrandr, xinput

DISPLAY_OUTPUT="eDP-1"
TOUCHSCREEN="ELAN24CC:00 04F3:24CC"
STYLUS="ELAN24CC:00 04F3:24CC Stylus Pen (0)"

# Coordinate transformation matrices for each orientation
declare -A ROTATION_MAP=(
    ["normal"]="normal"
    ["bottom-up"]="inverted"
    ["right-up"]="right"
    ["left-up"]="left"
)

declare -A CTM=(
    ["normal"]="1 0 0 0 1 0 0 0 1"
    ["inverted"]="-1 0 1 0 -1 1 0 0 1"
    ["right"]="0 1 0 -1 0 1 0 0 1"
    ["left"]="0 -1 1 1 0 0 0 0 1"
)

apply_rotation() {
    local orientation="$1"
    local rotation="${ROTATION_MAP[$orientation]}"
    local matrix="${CTM[$rotation]}"

    [ -z "$rotation" ] && return

    xrandr --output "$DISPLAY_OUTPUT" --rotate "$rotation" 2>/dev/null

    for device in "$TOUCHSCREEN" "$STYLUS"; do
        xinput set-prop "$device" "Coordinate Transformation Matrix" $matrix 2>/dev/null
    done
}

last_orientation=""

monitor-sensor 2>/dev/null | while read -r line; do
    if [[ "$line" =~ "Accelerometer orientation changed:" ]]; then
        orientation="${line##*: }"
        if [ "$orientation" != "$last_orientation" ]; then
            apply_rotation "$orientation"
            last_orientation="$orientation"
        fi
    fi
done
