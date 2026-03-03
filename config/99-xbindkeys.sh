#!/bin/bash
# Resume hook for suspend/hibernate
# - Reset display rotation to normal before sleep (i915 can't restore rotated state on hibernate resume)
# - Restart xbindkeys and reapply xmodmap after resume (xbindkeys loses key grabs)

XENV="DISPLAY=:0 XAUTHORITY=/home/shahmir/.Xauthority"

if [ "$1" = "pre" ]; then
    su shahmir -c "$XENV xrandr --output eDP-1 --rotate normal"
fi

if [ "$1" = "post" ]; then
    sleep 2
    su shahmir -c "$XENV xmodmap /home/shahmir/.Xmodmap"
    su shahmir -c "$XENV killall xbindkeys 2>/dev/null; $XENV xbindkeys"
fi
