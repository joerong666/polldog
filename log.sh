
log_level=0

log_debug() {
    [ $log_level -le 0 ] && echo "[`date +'%Y-%m-%d %H:%M:%S'` DEBUG] $1"
}

log_info() {
    [ $log_level -le 1 ] && echo "[`date +'%Y-%m-%d %H:%M:%S'` INFO] $1"
}

log_warn() {
    [ $log_level -le 2 ] && echo "[`date +'%Y-%m-%d %H:%M:%S'` WARN] $1"
}

log_err() {
    echo "[`date +'%Y-%m-%d %H:%M:%S'` ERROR] $1"
}

log_fatal() {
    echo "[`date +'%Y-%m-%d %H:%M:%S'` FATAL] $1"
}

log_prompt() {
    echo "[`date +'%Y-%m-%d %H:%M:%S'` PROMPT] $1"
}
