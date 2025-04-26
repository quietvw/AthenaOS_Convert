#!/bin/bash
sleep 5
RES="960 640 60"
DISP=$(xrandr | grep " connected" | awk '{print $1}')
MODELINE=$(cvt $RES | grep -oP 'Modeline \K.*')
MODERES=$(echo $MODELINE | cut -d' ' -f1)

xrandr --newmode $MODELINE && \
xrandr --addmode $DISP $MODERES && \
xrandr --output $DISP --mode $MODERES

pcmanfm --set-wallpaper="/home/athenaos/wallpaper.png"

cd /home/athenaos/AthenaOS_UI && python3 main.py &
firefox --kiosk http://127.0.0.1:15500
