#!/bin/sh

cmd_list=$1
try_stop_times=1
log_file="`pwd`/poll_cmd_dog.log"

cd `dirname $0`
CMD=`basename $0`
PWD=`pwd`

log_level=1

log_debug() {
    [ $log_level -le 0 ] && echo "[ DEBUG `date +'%Y-%m-%d %H:%M:%S'` ] $1"
}

log_info() {
    [ $log_level -le 1 ] && echo "[ INFO `date +'%Y-%m-%d %H:%M:%S'` ] $1"
}

log_warn() {
    [ $log_level -le 2 ] && echo "[ WARN `date +'%Y-%m-%d %H:%M:%S'` ] $1"
}

log_err() {
    echo "[ ERROR `date +'%Y-%m-%d %H:%M:%S'` ] $1"
}

log_fatal() {
    echo "[ FATAL `date +'%Y-%m-%d %H:%M:%S'` ] $1"
}

log_prompt() {
    echo "[ PROMPT `date +'%Y-%m-%d %H:%M:%S'` ] $1"
}

#already exist
cnt=`ps x -o command |fgrep "$CMD $cmd_list" |fgrep -v fgrep |awk '{print $2}' |fgrep "$CMD" |wc -l`
if [ $cnt -gt 2 ]; then
    log_debug "[`date +'%Y-%m-%d %H:%M:%S'` ] [$CMD $cmd_list] already exist, exit!!"
    exit 1
fi

log_prompt "start $CMD for watching commands in $cmd_list"

#add to crontab
rs=`crontab -l |fgrep "$CMD $cmd_list" |fgrep -v fgrep`
if [ -z "$rs" ]; then
    crontab -l > .mycrontab 2> /dev/null
    job_cmd="* * * * *  $PWD/$CMD $cmd_list >> $log_file 2>1 &"
    log_info "add [$CMD $cmd_list] to crontab"
    echo "$job_cmd" >>.mycrontab
    crontab .mycrontab
    rm .mycrontab
fi

while [ 1 -eq 1 ];
do
    test -e $cmd_list || touch $cmd_list

    if [ `wc -l $cmd_list |awk '{print $1}'` -eq 0 ]; then
        log_debug "no cmd in $cmd_list for watch, try times=$try_stop_times"
        try_stop_times=`expr $try_stop_times + 1`
        if [ $try_stop_times -gt 5 ]; then
            #del from crontab
            rs=`crontab -l |fgrep "$CMD $cmd_list"`
            if [ -n "$rs" ]; then
                log_info "del [$CMD $cmd_list] from crontab"
                crontab -l > .mycrontab 2> /dev/null
                lnum=`fgrep -n "$CMD $cmd_list" .mycrontab |awk -F: '{print $1}' |head -1`
                sed -i "${lnum}d" .mycrontab
                crontab .mycrontab
                rm .mycrontab
            fi  
            
                        log_prompt "try times=$try_stop_times reach end, exit!!"
            exit 0
        fi

        sleep 2
        continue
    fi

    if [ $try_stop_times -gt 1 ]; then
        log_debug "cmd found $cmd_list, return normal"
        try_stop_times=1
    fi

    cat $cmd_list |while read line
    do
        dname="`dirname "$line"`"
        bname="`basename "$line"`"
        proc=`ps x|fgrep "$bname"  |fgrep -v "$0" |fgrep -v "fgrep"`

        if [ -z "$proc" ]; then
            cd $dname
            full_cmd="`pwd`/$bname"

            log_prompt "poll and start [$full_cmd]"
            log_prompt "poll and start [$full_cmd]" >>start.log
            nohup $full_cmd >>start.log 2>&1 &
        fi
    done

    sleep 2
done
