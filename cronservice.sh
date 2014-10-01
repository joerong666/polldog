#!/bin/env bash

cd `dirname $0`
g_pwd=`pwd`
CURRENT_FILE=`basename $0`

g_method="$1"
g_service="$2"
g_basedir="$3"

METHODS="check_start|start|stop|restart"
SERVICES="web_admin|web_api|mgr|func_master|func_slave"

source log.sh

usage()
{
    echo "Usage: $0 [$METHODS] [$SERVICES] base_dir"
    exit 1
}

function op_web() {
    method="$1"
    base_dir="$2"

    log_debug "op_web: $*"
    if [ -z "$method" -o -z "$base_dir" ]; then
        log_err "method or base_dir empty" 
        return 1
    fi

    case "$method" in
        "start") ./autocron.sh -m start -c "$g_pwd/$CURRENT_FILE check_start $g_service $g_basedir && play start" -d "$base_dir"
            ;;
        "stop") ./autocron.sh -m stop -c "play stop; rm -f $base_dir/server.pid" -d "$base_dir" -e "play start"
            ;;
        "restart") ./autocron.sh -m restart -c "play restart" -d "$base_dir"
            ;;
    esac
}

function op_mgr() {
    method="$1"
    base_dir="$2"

    log_debug "op_mgr: $*"
    if [ -z "$method" -o -z "$base_dir" ]; then
        log_err "method or base_dir empty" 
        return 1
    fi

    case "$method" in
        "start") ./autocron.sh -m start -c "$g_pwd/$CURRENT_FILE check_start $g_service $g_basedir && $base_dir/uchas -f fooyun_mngr.ini -d" -d "$base_dir"
            ;;
        "stop") ./autocron.sh -m stop -c "ps x |fgrep \"$base_dir/uchas\"|fgrep -v 'fgrep' |awk '{print \$1}' |xargs kill -9" -d "$base_dir" -e "$base_dir/uchas -f fooyun_mngr.ini"
            ;;
        "restart") 
            ./autocron.sh -m stop -c "ps x|grep \"$base_dir/uchas\"|grep -v 'grep' |awk '{print \$1}' |xargs kill -9" -d "$base_dir" -e "$base_dir/uchas -f fooyun_mngr.ini" && \
            ./autocron.sh -m start -c "$base_dir/uchas -f fooyun_mngr.ini -d" -d "$base_dir"
            ;;
    esac
}

function op_func() {
    method="$1"
    base_dir="$2"
    func_role="$3"

    log_debug "op_func: $*"
    if [ -z "$method" -o -z "$base_dir" -o -z "$func_role" ]; then
        log_err "method or base_dir or func_role empty" 
        return 1
    fi

    case "$method" in
        "start") ./autocron.sh -m start -c "$g_pwd/$CURRENT_FILE check_start $g_service $g_basedir && $base_dir/python $func_role --daemon" -d "$base_dir"
            ;;
        "stop") ./autocron.sh -m stop -c "ps x |fgrep \"$base_dir/python $func_role\" |grep -v 'grep' |awk '{print \$1}' |xargs kill -9" -d "$base_dir" -e "$base_dir/python $func_role"
            ;;
        "restart") 
            ./autocron.sh -m stop -c "ps x|grep \"$base_dir/python $func_role\" |grep -v 'grep' |awk '{print \$1}' |xargs kill -9" -d "$base_dir" -e "$base_dir/python $func_role" && \
            ./autocron.sh -m start -c "$base_dir/python $func_role --daemon" -d "$base_dir"
            ;;
    esac
}

###########################
# return 0: ready to start
# return 1: not ready to start
###########################
function check_start() {
    case "$g_service" in
        "web_admin"|"web_api") 
            log_debug "check whether $g_basedir/server.pid eixist"
            [ ! -f $g_basedir/server.pid ] && return 0

            log_debug "check whether $g_service exist according to $g_basedir/server.pid"
            proc_dir="`cat $g_basedir/server.pid |xargs pwdx |fgrep -v 'No such process' |awk '{print $2}'`"
            [ -z "$proc_dir" -o "$proc_dir" != "$g_basedir" ] && rm $g_basedir/server.pid && return 0

            log_debug "hit proc[pid:`cat $g_basedir/server.pid`]"
            return 1
            ;;
        "mgr") 
            log_debug "check whether $g_service exist"
            proc="`ps x |fgrep "$g_basedir/uchas" |fgrep -v "$CURRENT_FILE" |fgrep -v 'fgrep'`"
            [ -z "$proc" ] && return 0

            log_debug "hit proc[$proc]"
            return 1
            ;;
        "func_master") 
            log_debug "check whether $g_serivce exist"
            proc="`ps x |fgrep "$g_basedir/python certmaster" |fgrep -v "$CURRENT_FILE" |fgrep -v 'fgrep'`"
            [ -z "$proc" ] && return 0

            log_debug "hit proc[$proc]"
            return 1
            ;;
        "func_slave") 
            log_debug "check whether $g_service exist"
            proc="`ps x |fgrep "$g_basedir/python funcd" |fgrep -v "$CURRENT_FILE" |fgrep -v 'fgrep'`"
            [ -z "$proc" ] && return 0

            log_debug "hit proc[$proc]"
            return 1
            ;;
    esac
}

[ $# -ne 3 ] && usage
[ -z "`echo $g_method  |egrep "$METHODS"`" ] && usage
[ -z "`echo $g_service |egrep "$SERVICES"`" ] && usage

if [ "$g_method" == "check_start" ]; then
    $g_method
    ecode=$?

    if [ $ecode -eq 0 ]; then
        log_info "process not exist, you can start it"
    else
        log_info "process exist, should not start again"
    fi
else
    log_prompt "---------- begin to $g_method $g_service ---------------"
    case "$g_service" in
        "web_admin"|"web_api") op_web $g_method $g_basedir; ecode=$?
            ;;
        "mgr") op_mgr $g_method $g_basedir; ecode=$?
            ;;
        "func_master") op_func $g_method $g_basedir "certmaster"; ecode=$?
            ;;
        "func_slave") op_func  $g_method $g_basedir "funcd"; ecode=$?
            ;;
    esac

    if [ $ecode -eq 0 ]; then
        log_prompt "$g_method $g_service success"
    else
        log_err "$g_method $g_service fail"
    fi

    log_prompt "----------- $g_method $g_service finished ---------------"
fi

exit $ecode
