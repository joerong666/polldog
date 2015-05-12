#!/bin/sh

###################################################
# usage: ./cmd_dog.sh cmd_list_file
###################################################

cmd_list=$1
try_stop_times=1

cd `dirname $0`
CMD=`basename $0`
PWD=`pwd`
LOG="start.log"

echo "`date +'%Y-%m-%d %H:%M:%S'` start $CMD for watching commands in $cmd_list"

#already exist
cnt=`ps x -o command |fgrep "$CMD $cmd_list" |fgrep -v fgrep |awk '{print $2}' |fgrep "$CMD" |wc -l`
if [ $cnt -gt 2 ]; then
    echo "`date +'%Y-%m-%d %H:%M:%S'` [$CMD $cmd_list] already exist, exit!!"
    exit 1
fi

#add to crontab
rs=`crontab -l |fgrep "$CMD $cmd_list" |fgrep -v fgrep`
if [ -z "$rs" ]; then
    crontab -l > .mycrontab 2> /dev/null
    job_cmd="* * * * *  $PWD/$CMD $cmd_list > $PWD/$LOG 2>&1 &"
    echo "add [$CMD $cmd_list] to crontab"
    echo "$job_cmd" >>.mycrontab
    crontab .mycrontab
    rm .mycrontab
fi

while [ 1 -eq 1 ];
do
    test -e $cmd_list || touch $cmd_list

    if [ `wc -l $cmd_list |awk '{print $1}'` -eq 0 ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` no cmd in $cmd_list for watch, try times=$try_stop_times"
        try_stop_times=`expr $try_stop_times + 1`
        if [ $try_stop_times -gt 5 ]; then
            echo "`date +'%Y-%m-%d %H:%M:%S'` try times=$try_stop_times reach end!!"

            #del from crontab
            rs=`crontab -l |fgrep "$CMD $cmd_list"`
            if [ -n "$rs" ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` del [$CMD $cmd_list] from crontab"
                crontab -l > .mycrontab 2> /dev/null
                lnum=`fgrep -n "$CMD $cmd_list" .mycrontab |awk -F: '{print $1}'`
                sed -i "${lnum}d" .mycrontab
                crontab .mycrontab
                #rm .mycrontab
            fi  

            echo "`date +'%Y-%m-%d %H:%M:%S'` exit!!"
            exit 0
        fi  

        sleep 2
        continue
    fi  

    if [ $try_stop_times -gt 1 ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` cmd found $cmd_list, return normal"
        try_stop_times=1
    fi  
    
    cat $cmd_list |while read line
    do  
        proc=`ps x|fgrep "$line"  |fgrep -v "$0" |fgrep -v "fgrep"`
        if [ -z "$proc" ]; then
            echo "`date +'%Y-%m-%d %H:%M:%S'` poll and start [$line]"
            nohup $line >>$LOG 2>&1 &
        fi  
    done

    sleep 2
done
