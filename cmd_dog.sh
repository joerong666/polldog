#!/bin/sh

###################################################
# usage: nohup ./cmd_dog.sh your_cmd >>start.log &
###################################################

cmd=$*

while [ 1 -eq 1 ];
do
    proc=`ps x|fgrep "$cmd"  |fgrep -v "$0" |fgrep -v "fgrep"`
    if [ "$proc" == "" ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` poll and start [$cmd]"
        $cmd >>start.log 2>&1
    fi 
    sleep 2
done
