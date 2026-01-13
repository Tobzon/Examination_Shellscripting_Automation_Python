#!/bin/bash


#genomföra minst en säkerhetskontroll, exempelvis:
#kontroll av filrättigheter
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


checkNetwork() {
local threshold=100

#listar upp alla tcp och udp sockets i numeric form, 1 per rad
count=$(ss -ntu | wc -l)

if((count > threshold)); then
    log "Ovanligt många nätverksansutningar: $count"
fi

jounralctl -u sshd \
    | grep -Ei "Accepted|Failed" \
    | awk '{print $(NF-3)}' \
    | sort -u > -a $logFile
}



checkSystemLogs() {

local logSearch="/var/log/syslog"
local words="error|fail|critical"

# hämtar logs med error,fail,critical i syslog o skriver ner dom i en ny fil, -Ei gör så att man kan göra uttryck utan backslahes(E,en slags regex användning) och den är inte case-senseitive(i) 
grep -Ei "$words" "$logSearch" > syslogs.log
}

fileCheck() {

local file=$1

if [ ! -f "$file"]; then
    log "FEL: Filen "$file" existerar inte "
fi 

if [ -r "$file"]; then 
    log "filen "$file" går att läsa"
else
    log "FEL: Filen "$file" går inte att läsa"
    
fi

if [ -w "$file"]; then
    log "filen "$file" går att redigera"
else
    log "FEL: filen "$file" går inte att redigera"
fi
}