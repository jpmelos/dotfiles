setxkbmap br &
unclutter -idle 3 -noevents -root &
xdotool mousemove 0 0
exec openbox-session
