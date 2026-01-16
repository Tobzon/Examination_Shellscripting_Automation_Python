#!/usr/bin/env bash
set -euo pipefail

# ===== FÄRGER =====
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="\e[0m"

# Skriver ut en tydlig sektionsrubrik, tar emot en sträng som rubrik
section() {
    echo -e "\n${CYAN}========================================${RESET}"
    echo -e "${CYAN} $1${RESET}"
    echo -e "${CYAN}========================================${RESET}"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[VARNING]${RESET} $1"
}

fail() {
    echo -e "${RED}[FEL]${RESET} $1"
}

info() {
    echo -e "${MAGENTA}[INFO]${RESET} $1"
}



logFile="logs.log"

#Loggar meddelande till logfilen med svensk tidsformat
log() {
    local msg="$1"
    echo "$(LC_TIME=sv_SE.UTF-8 date '+%F %T') - $msg" >> "$logFile"
}

#Global felhanterare som triggas om ett kommando misslyckas
error_handler() {
    log "FEL (${BASH_SOURCE[1]}:${BASH_LINENO[0]}): kommando misslyckades"
    exit 1
}

trap error_handler ERR


#listar upp alla tcp och udp sockets i numeric form, 1 per rad
checkNetwork() {
    section "Nätverksanslutningar"

    local threshold=100
    local count

    if ! count=$(ss -ntu 2>/dev/null | wc -l); then
        fail "Kunde inte läsa nätverksanslutningar"
        log "FEL: kunde inte läsa nätverksanslutningar"
        return 1
    fi

    info "Antal aktiva sockets: $count"

    if (( count > threshold )); then
        warn "Ovanligt många nätverksanslutningar ($count)"
        log "VARNING: Ovanligt många nätverksanslutningar ($count)"
    else
        ok "Nätverksanslutningar ser normala ut"
        log "Nätverksanslutningar OK ($count)"
    fi
}

# Kontrollerar SSH-inloggningar via systemd journal, letar efter både lyckade och misslyckade försök
checkSsh() {
    section "SSH-inloggningar"

    if ! command -v journalctl >/dev/null; then
        fail "journalctl saknas"
        log "FEL: journalctl saknas"
        return 1
    fi

    local hits
    hits=$(journalctl -u ssh 2>/dev/null | grep -Ei "Accepted|Failed" | sort -u | wc -l)

    if (( hits > 0 )); then
        warn "SSH-försök hittades ($hits)"
        journalctl -u ssh | grep -Ei "Accepted|Failed" | sort -u >> "$logFile"
    else
        ok "Inga SSH-försök hittades"
        log "Inga SSH-försök"
    fi
}

# Kontrollerar om systemuppdateringar finns tillgängliga
checkUpdates() {
    section "Systemuppdateringar"

    local updates

    if ! updates=$(apt list --upgradable 2>/dev/null); then
        fail "Kunde inte kontrollera uppdateringar"
        log "FEL: Kunde inte kontrollera uppdateringar"
        return 1
    fi

    if echo "$updates" | grep -q upgradable; then
        warn "Det finns tillgängliga uppdateringar"
        echo "$updates" | grep security >> "$logFile" || true
        log "Uppdateringar finns"
    else
        ok "Systemet är uppdaterat"
        log "Systemet är uppdaterat"
    fi
}

# Kontrollerar en specifik fil:
# - att den finns
# - att den går att läsa
# - om den är skrivbar (kan vara en säkerhetsrisk)
fileCheck() {
    section "Filkontroll: $1"

    local file="${1:-}"

    if [[ -z "$file" ]]; then
        fail "Ingen fil angiven"
        log "FEL: Ingen fil angiven"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        fail "Filen existerar inte: $file"
        log "FEL: Filen existerar inte: $file"
        return 1
    fi

    [[ -r "$file" ]] \
        && ok "Filen går att läsa" \
        || fail "Filen går inte att läsa"

    [[ -w "$file" ]] \
        && warn "Filen är skrivbar (kontrollera rättigheter)" \
        || ok "Filen är inte skrivbar"
}

# Huvudfunktionen som kör hela skriptet i rätt ordning
main() {
    section "LINUX SÄKERHETSRAPPORT"

    checkNetwork
    checkSsh
    checkUpdates
    fileCheck "/etc/passwd"

    section "Rapport klar"
}
main
