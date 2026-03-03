#!/bin/bash
# Wait for gpio-volume virtual keyboard before applying xmodmap,
# because a new X11 keyboard device appearing resets xmodmap.
# Then restart xbindkeys so it grabs the remapped keysyms (e.g. XF86MonBrightnessDown/Up).
timeout 30 bash -c 'until xinput list 2>/dev/null | grep -q "volume-buttons"; do sleep 1; done'
sleep 1
xmodmap /home/shahmir/.Xmodmap
killall xbindkeys 2>/dev/null
xbindkeys
