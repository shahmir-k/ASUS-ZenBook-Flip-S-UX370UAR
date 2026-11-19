#!/bin/bash
# Resume hook for suspend/hibernate
# - Unload Intel ISH modules before hibernate (ISH fails to reinitialize after S4, causing system freeze)
# - Reset display rotation to normal before sleep (i915 can't restore rotated state on hibernate resume)
# - Reload ISH and restart xbindkeys/xmodmap after resume
# - Restart Cinnamon after hibernate (muffin compositor loses GPU context on S4 resume)

XENV="DISPLAY=:0 XAUTHORITY=/home/shahmir/.Xauthority"
LOG="logger -t sleep-hook"

if [ "$1" = "pre" ]; then
    $LOG "pre-sleep: starting ($2)"
    timeout 5 su shahmir -c "$XENV xrandr --output eDP-1 --rotate normal" 2>/dev/null || $LOG "xrandr rotate timed out"
    # Unload ISH before hibernate — it hangs on S4 resume if loaded
    timeout 5 modprobe -r intel_ishtp_hid 2>/dev/null || $LOG "modprobe -r intel_ishtp_hid failed"
    timeout 5 modprobe -r intel_ish_ipc 2>/dev/null || $LOG "modprobe -r intel_ish_ipc failed"
    timeout 5 modprobe -r intel_ishtp 2>/dev/null || $LOG "modprobe -r intel_ishtp failed"
    $LOG "pre-sleep: done"
fi

if [ "$1" = "post" ]; then
    $LOG "post-resume: starting ($2)"
    # Reload ISH modules (timeout each — hw start can hang after S4)
    timeout 10 modprobe intel_ishtp 2>/dev/null || $LOG "modprobe intel_ishtp failed/timed out"
    timeout 10 modprobe intel_ish_ipc 2>/dev/null || $LOG "modprobe intel_ish_ipc failed/timed out"
    timeout 10 modprobe intel_ishtp_hid 2>/dev/null || $LOG "modprobe intel_ishtp_hid failed/timed out"

    # Restart Cinnamon compositor in a fully detached background process
    # so it cannot block the sleep hook from completing
    (
        sleep 3
        su shahmir -c "$XENV cinnamon --replace" &
        sleep 4
        su shahmir -c "$XENV cinnamon-screensaver-command --lock" 2>/dev/null
        su shahmir -c "$XENV xmodmap /home/shahmir/.Xmodmap"
        su shahmir -c "$XENV killall xbindkeys 2>/dev/null; $XENV xbindkeys"
        $LOG "post-resume: background tasks done"
    ) &
    disown

    $LOG "post-resume: done (background tasks spawned)"
fi
