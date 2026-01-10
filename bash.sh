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



fileCheck() {

local file=$1

if [ -e "$file"]; then
    log "filen existerar"
fi 

if [ -r "$file"]; then 
    log "filen går att läsa"
fi

if [ -w "$file"]; then
    log "filen går att redigera"
fi
}