#!/bin/bash


#genomföra minst en säkerhetskontroll, exempelvis:
#analys av systemloggar
#upptäckt av ovanlig nätverkstrafik
#kontroll av installerade paket och uppdateringsstatus
#innehålla strukturerad felhantering
#logga output i en fil
#följa best practice för shellscript 


logFile="logs"



log() {
    echo "$(LC_TIME=sv_SE.UTF-8 date '+%F %T') -$1" | tee -a $logFile
}

#listar upp alla tcp och udp sockets i numeric form, 1 per rad
checkNetwork() {
local threshold=100

count=$(ss -ntu | wc -l)

if [ $count -gt $threshold ]; then
    log "Ovanligt många nätverksanslutningar: $count"
fi
}

checkSsh() {
    jounralctl -u sshd \
    | grep -Ei "Accepted|Failed" \
    | awk '{print $(NF-3)}' \
    | sort -u >> $logFile
}

checkUpdates() {
if apt list --upgradable 2>/dev/null | grep -q upgradable; then
    log "Det finns uppdateringar"
    sudo apt update -qq
    
else
    log "Systemet är uppdaterat"
fi
}

fileCheck() {

local file=$1

echo "Kontrollerar filrättigheter..."

if [ ! -f "$file" ]; then
    log "FEL: Filen "$file" existerar inte "
fi 

if [ -r "$file" ]; then 
    log "filen "$file" går att läsa"
else
    log "FEL: Filen "$file" går inte att läsa"
fi

if [ -w "$file" ]; then
    log "filen "$file" går att redigera"
else
    log "FEL: filen "$file" går inte att redigera"
fi
}

