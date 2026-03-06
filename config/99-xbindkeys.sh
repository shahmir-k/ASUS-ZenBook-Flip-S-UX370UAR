#!/bin/bash
# Resume hook for suspend/hibernate
# - Unload Intel ISH modules before hibernate (ISH fails to reinitialize after S4, causing system freeze)
# - Reset display rotation to normal before sleep (i915 can't restore rotated state on hibernate resume)
# - Reload ISH and restart xbindkeys/xmodmap after resume

XENV="DISPLAY=:0 XAUTHORITY=/home/shahmir/.Xauthority"

if [ "$1" = "pre" ]; then
    su shahmir -c "$XENV xrandr --output eDP-1 --rotate normal"
    # Unload ISH before hibernate — it hangs on S4 resume if loaded
    modprobe -r intel_ishtp_hid 2>/dev/null
    modprobe -r intel_ish_ipc 2>/dev/null
    modprobe -r intel_ishtp 2>/dev/null
fi

if [ "$1" = "post" ]; then
    # Reload ISH modules
    modprobe intel_ishtp 2>/dev/null
    modprobe intel_ish_ipc 2>/dev/null
    modprobe intel_ishtp_hid 2>/dev/null
    sleep 2
    su shahmir -c "$XENV xmodmap /home/shahmir/.Xmodmap"
    su shahmir -c "$XENV killall xbindkeys 2>/dev/null; $XENV xbindkeys"
fi
