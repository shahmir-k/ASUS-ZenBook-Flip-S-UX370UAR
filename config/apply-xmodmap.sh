#!/bin/bash
# Wait for input-remapper virtual keyboard before applying xmodmap,
# because input-remapper creating a new X11 keyboard device resets xmodmap.
timeout 30 bash -c 'until xinput list 2>/dev/null | grep -q "input-remapper keyboard"; do sleep 1; done'
sleep 1
xmodmap /home/shahmir/.Xmodmap
