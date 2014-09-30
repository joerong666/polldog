#!/bin/env bash

BASE=`pwd`
TMP=./tmp

source log.sh

usage()
{
    echo "Usage: $0 [-m start|stop|restart] [-c cmd] [-e cmd_regexp] [-d base_dir]"
    exit 1
}

# crontab functions
add_to_crontab()
{
    RES=`crontab -l | grep -v "^#" | fgrep "$base_dir" |fgrep "$cmd"`
    if [ -z "$RES" ]; then
        mkdir -p $TMP
        CRON=$TMP/.cron
        crontab -l > $CRON 2> /dev/null
        job_cmd="* * * * * source ~/.bash_profile && source ~/.bashrc && cd $base_dir && ($cmd) > cron.log 2>&1"
        echo "$job_cmd" >> $CRON

        log_debug "add cronjob: $job_cmd"
        crontab $CRON
        if [ $? -eq 0 ]; then
            log_info "job added, check your crontab via 'crontab -l'"
        else
            log_err "'crontab $CRON' failure, please check the file"
            exit 1
        fi
    fi
}

del_from_crontab()
{
    RES=`crontab -l |fgrep -n "$base_dir" |fgrep "$cmd_regexp" |grep -v "^#" |awk -F: '{print $1}'`
    if [ ! -z "$RES" ]; then
        mkdir -p $TMP
        CRON=$TMP/.cron
        crontab -l > $CRON 2> /dev/null
        job_cmd=`sed -n "${RES}p" $CRON`
        sed -i "${RES}d" "$CRON"
        log_debug "delete cronjob: $job_cmd"
        crontab "$CRON"
        if [ $? -eq 0 ]; then
            log_info "job deleted, check your crontab via 'crontab -l'"
        else
            log_err "'crontab $CRON' failure, please check the file"
            exit 1
        fi
   fi
}

while getopts m:c:e:d: ac
do
    case $ac in
        m)  method="$OPTARG"
            ;;
        c)  cmd="$OPTARG"
            ;;
        e)  cmd_regexp="$OPTARG"
            ;;
        d)  base_dir="$OPTARG"
            ;;
        \?) echo "invalid args"
            exit 1
            ;;
    esac
done

[ -z "$method" -o  -z "$cmd" -o -z "$base_dir" ] && usage
[ -z `echo "$method" |egrep "start|stop|restart"` ] && usage

if [ "$method" = "stop" -a -z "$cmd_regexp" ]; then
    log_err "cmd_regexp needed for grep cmd to stop"
    usage
fi

log_info "run cmd[cd $base_dir && $cmd]"
cd $base_dir && eval $cmd

if [ $? -ne 0 ]; then
    log_err "run cmd[cd $base_dir && eval $cmd] failed"
    exit 1
fi

case "$method" in
    "start") 
    log_debug "modify crontab if needed"
    add_to_crontab
    ;;
    "stop") 
    log_debug "modify crontab if needed"
    del_from_crontab
    ;;
esac
