#!/bin/sh

cd ~/scripts/gcal-ticker
DZEN_OPTS=" -bg black -xs 2 -ta l -fn 6x12 "
./ticker.pl $@ | dzen2 $DZEN_OPTS 2> /dev/null
