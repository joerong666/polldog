#!/bin/env bash

g_method="$1"
g_service="$2"

METHODS="check_start|start|stop|restart"
SERVICES="web_admin|web_api|mgr|func_master|func_slave"

usage()
{
    echo "Usage: $0 [$METHODS] [$SERVICES]"
    exit 1
}

[ $# -ne 2 ] && usage
[ -z "`echo $g_method  |egrep "$METHODS"`" ] && usage
[ -z "`echo $g_service |egrep "$SERVICES"`" ] && usage


############################
# customize basedir
############################
web_admin_basedir=$HOME/local/fooyun/fooyun-web-beta
web_api_basedir=$HOME/local/fooyun/fooyun-web-beta_cls
mgr_basedir=$HOME/local/fooyun/fooyun-mngrserver-beta_x86_64/bin
func_master_basedir=$HOME/local/func/func_all_in-uc-bin_x64/bin
func_slave_basedir=$HOME/local/func/func_all_in-uc-bin_x64/bin

basedir="\$${g_service}_basedir"
./cronservice.sh $g_method $g_service `eval "echo $basedir"`
