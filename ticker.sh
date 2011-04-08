#!/bin/sh

DZEN_OPTS=" -bg '#000000' -xs 2 -ta l -fn 6x12 "
./ticker.pl $@ | dzen2 $DZEN_OPTS 2> /dev/null
