#!/bin/env bash

PWD=`dirname $0`
METHODS="start|stop|restart"
SERVICES="web_admin|web_api|mgr|func_master|func_slave"
log_level="debug"
g_method="$1"
g_service="$2"
g_basedir="$3"

usage()
{
    echo "Usage: $0 [$METHODS] [$SERVICES] base_dir"
    exit 1
}

log_debug() {
    [ "$log_level" == "debug" ] && echo "[`date +'%Y-%m-%d %H:%M:%S'` DEBUG] $1"
}

log_info() {
    echo "[`date +'%Y-%m-%d %H:%M:%S'` INFO] $1"
}

log_err() {
    echo "[`date +'%Y-%m-%d %H:%M:%S'` ERROR] $1"
}

function op_web() {
    method="$1"
    base_dir="$2"

    log_debug "op_web: $*"
    if [ -z "$method" -o -z "$base_dir" ]; then
        log_err "method or base_dir empty" 
        exit 1
    fi

    case "$method" in
        "start") $PWD/start_check.sh $g_service $g_basedir && ./cronservice.sh -m start -c "play start" -d "$base_dir"
            ;;
        "stop") ./cronservice.sh -m stop -c "play stop" -d "$base_dir" -e "play start"
            ;;
        "restart") ./cronservice.sh -m restart -c "play restart" -d "$base_dir"
            ;;
    esac
}

function op_mgr() {
    method="$1"
    base_dir="$2"

    log_debug "op_mgr: $*"
    if [ -z "$method" -o -z "$base_dir" ]; then
        log_err "method or base_dir empty" 
        exit 1
    fi

    case "$method" in
        "start") $PWD/start_check.sh $g_service $g_basedir && ./cronservice.sh -m start -c "$base_dir/uchas -f fooyun_mngr.ini -d" -d "$base_dir"
            ;;
        "stop") ./cronservice.sh -m stop -c "ps x |fgrep \"$base_dir/uchas\"|fgrep -v 'fgrep' |awk '{print \$1}' |xargs kill -9" -d "$base_dir" -e "$base_dir/uchas -f fooyun_mngr.ini"
            ;;
        "restart") 
            ./cronservice.sh -m stop -c "ps x|grep \"$base_dir/uchas\"|grep -v 'grep' |awk '{print \$1}' |xargs kill -9" -d "$base_dir" -e "$base_dir/uchas -f fooyun_mngr.ini" && \
            ./cronservice.sh -m start -c "$base_dir/uchas -f fooyun_mngr.ini -d" -d "$base_dir"
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
        exit 1
    fi

    case "$method" in
        "start") $PWD/start_check.sh $g_service $g_basedir && ./cronservice.sh -m start -c "$base_dir/python $func_role --daemon" -d "$base_dir"
            ;;
        "stop") ./cronservice.sh -m stop -c "ps x |fgrep \"$base_dir/python $func_role\" |grep -v 'grep' |awk '{print \$1}' |xargs kill -9" -d "$base_dir" -e "$base_dir/python $func_role"
            ;;
        "restart") 
            ./cronservice.sh -m stop -c "ps x|grep \"$base_dir/python $func_role|grep -v 'grep' |awk '{print \$1}'\" |xargs kill -9" -d "$base_dir" -e "$base_dir/python $func_role" && \
            ./cronservice.sh -m start -c "$base_dir/python $func_role --daemon" -d "$base_dir"
            ;;
    esac
}

[ $# -ne 3 ] && usage
[ -z "`echo $1 |egrep "$METHODS"`" ] && usage
[ -z "`echo $2 |egrep "$SERVICES"`" ] && usage

log_info "---------- begin to $1 $2 ---------------"
case "$2" in
    "web_admin") op_web $1 $3 
        ;;
    "web_api") op_web $1 $3
        ;;
    "mgr") op_mgr $1 $3
        ;;
    "func_master") op_func $1 $3 "certmaster"
        ;;
    "func_slave") op_func $1 $3 "funcd"
        ;;
esac
log_info "----------- $1 $2 finished ---------------"

