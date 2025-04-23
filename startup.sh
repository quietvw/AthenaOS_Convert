#!/bin/bash
sleep 5
RES="800 400 60"
DISP=$(xrandr | grep " connected" | awk '{print $1}')
MODELINE=$(cvt $RES | grep -oP 'Modeline \K.*')
MODERES=$(echo $MODELINE | cut -d' ' -f1)

xrandr --newmode $MODELINE && \
xrandr --addmode $DISP $MODERES && \
xrandr --output $DISP --mode $MODERES

pcmanfm --set-wallpaper="/home/athenaos/wallpaper.png"

cd /home/athenaos/AthenaOS_UI && BROWSER=firefox python3 main.py
