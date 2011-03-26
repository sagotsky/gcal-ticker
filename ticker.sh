#!/bin/sh

cd ~/scripts/gcal-ticker/
./ticker.pl $@ | dzen2 -bg '#000000' -xs 2 -ta l -fn 6x12 
