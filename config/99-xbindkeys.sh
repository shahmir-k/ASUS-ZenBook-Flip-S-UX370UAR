#!/bin/bash
# Restart xbindkeys and reapply xmodmap after resume — xbindkeys loses
# key grabs after suspend/resume.
if [ "$1" = "post" ]; then
    sleep 2
    su shahmir -c 'DISPLAY=:0 xmodmap /home/shahmir/.Xmodmap'
    su shahmir -c 'DISPLAY=:0 killall xbindkeys 2>/dev/null; DISPLAY=:0 xbindkeys'
fi
