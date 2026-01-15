#!/usr/bin/env bash
set -euo pipefail


logFile="logs.log"

log() {
    local msg="$1"
    echo "$(LC_TIME=sv_SE.UTF-8 date '+%F %T') -$msg" | tee -a $logFile
}

error_handler() {
    log "FEL (${BASH_SOURCE[1]}:${BASH_LINENO[0]}): kommando misslyckades"
    exit 1
}

trap error_handler ERR


#listar upp alla tcp och udp sockets i numeric form, 1 per rad
checkNetwork() {
local threshold=100

if ! count=$(ss -ntu 2>/dev/null | wc -l)
    log "FEL: kunde nite läsa nästverksanslutningar"
    return 1

# (()) ist för [] då det är säkrare för heltal
if (( $count -gt $threshold )); then
    log "Ovanligt många nätverksanslutningar: $count"
fi
}

checkSsh() {

if ! command -v journalctl >/dev/null; then
        log "FEL: journalctl saknas"
        return 1
fi

journalctl -u sshd \
    | grep -Ei "Accepted|Failed" \
    | awk '{print $(NF-3)}' \
    | sort -u >> "$logFile" || \
    log "FEL: kunde inte läsa ssh-loggar"
}

checkUpdates() {
 local updates

    if ! updates=$(apt list --upgradable 2>/dev/null); then
        log "FEL: Kunde inte kontrollera uppdateringar"
        return 1
    fi

    echo "$updates" | grep security >> "$logFile"

    if echo "$updates" | grep -q upgradable; then
        log "Det finns uppdateringar"
    else
        log "Systemet är uppdaterat"
    fi
}

fileCheck() {

 local file="$1"

if [[ -z "$file" ]]; then
    log "FEL: Ingen fil angiven"
    return 1
fi

if [[ ! -f "$file" ]]; then
    log "FEL: Filen $file existerar inte"
    return 1
fi

[[ -r "$file" ]] \
    && log "Filen $file går att läsa" \
    || log "FEL: Filen $file går inte att läsa"

[[ -w "$file" ]] \
    && log "Filen $file går att redigera" \
    || log "FEL: Filen $file går inte att redigera"
}


main() {
    checkNetwork
    checkSsh
    checkUpdates
    fileCheck 
}