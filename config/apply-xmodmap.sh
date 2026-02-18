#!/bin/bash
# Wait for gpio-volume virtual keyboard before applying xmodmap,
# because a new X11 keyboard device appearing resets xmodmap.
timeout 30 bash -c 'until xinput list 2>/dev/null | grep -q "volume-buttons"; do sleep 1; done'
sleep 1
xmodmap /home/shahmir/.Xmodmap
