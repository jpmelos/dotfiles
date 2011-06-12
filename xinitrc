setxkbmap br &
unclutter -idle 3 -noevents -root &
xdotool mousemove 9999 9999
xset -dpms
xset s off
exec openbox-session
