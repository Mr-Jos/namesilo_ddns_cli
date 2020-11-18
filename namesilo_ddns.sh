#! /bin/bash
set -euo pipefail

## Namesilo DDNS without dependences
##   By Mr.Jos

## Requirements
##   Necessary: wget or curl
##   Optional : date, sleep

## ================= config ==================

declare APIKEY HOSTS

## Your API key and hosts for DDNS
# APIKEY="c40031261ee449037a4b44b1"
# HOST=(
#     "yourdomain1.tld"
#     "subdomain1.yourdomain1.tld"
#     "subdomain2.yourdomain2.tld"
# )

## ================ Settings =================

declare LOG LOG_LTH LOG_TIME REQ_INTERVAL REQ_RETRY

## Directories of log file (Default: in this script dir)
LOG="${0%/*}/namesilo_ddns.log"

## Max lines of log
LOG_LTH=2000

## Command for getting log header with time
## *Including optional requirement*
## (You can specify a time zone from command 'tzselect')
LOG_TIME=" TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S' "

## Command for setting interval between API requests
## *Including optional requirement*
REQ_INTERVAL=" sleep 5s "

## Retry limit for updating-failed host before disabled
REQ_RETRY=2

## ===========================================

if [[ -z $( command -v wget ) && -z $( command -v curl ) ]]; then
    echo "Necessary requirement (wget/curl) does not exist."
    exit 1
fi

declare IP_ADDR_V4 IP_ADDR_V6 INV_HOSTS RECORDS 
declare FORCE REFETCH FUNC_RETURN 
declare PROJECT COPYRIGHT HELP
PROJECT="Namesilo DDNS without dependences v2.0 (2020.11.18)"
COPYRIGHT="Copyright (c) 2020 Mr.Jos"
LICENSE="MIT License: <https://opensource.org/licenses/MIT>"
HELP="Usage: namesilo_ddns.sh <command> ... [parameters ...]
Commands:
  --help                   Show this help message.
  --version                Show version info.
  --key, -k <apikey>       Specify API key of Namesilo.
  --host, -h <host>        Add a host for DDNS.
  --force, -f              Force updating for unchanged IP.
  --refetch, -r            Refetch info of records.

Example:
  namesilo_ddns.sh -k c40031261ee449037a4b44b1 \\
      -h yourdomain1.tld \\
      -h subdomain1.yourdomain1.tld \\
      -h subdomain2.yourdomain2.tld

Tips:
  You had better to refetch records or delete log file,
  if your DNS records have been modified in other ways.
"

function parse_args()
{
    [[ $# -eq 0 ]] && return
    unset APIKEY HOSTS
    local VAR
    while [[ $# -gt 0 ]]; do case "$1" in
        --help)
            echo "${PROJECT:-}"
            echo "${HELP:-}"
            exit 0
            ;;
        --version)
            echo "${PROJECT:-}"
            echo "${COPYRIGHT:-}"
            echo "${LICENSE:-}"
            exit 0
            ;;
        --key | -k)
            shift
            if [[ $1 =~ ^[0-9a-f]{24}$ ]]; then
                APIKEY="$1"
            else
                echo "Invalid API key: $1"
                exit 1
            fi
            ;;
        --host | -h)
            shift
            VAR=(${1//./ })
            if [[ ${#VAR[@]} -ge 2 ]]; then
                HOSTS+=("$1")
            else
                echo "Invalid host format: $1"
                exit 1
            fi
            ;;
        --refetch | -r)
            REFETCH=true
            ;;
        --force | -f)
            FORCE=true
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac; shift; done
}

function load_log()
{
    ## read and parse old log
    local LINES=() IDX=0
    if [[ -e $LOG ]]; then
        local LINE CACHE
        while read -r LINE; do
            if [[ -z $LINE ]]; then
                continue
            elif [[ ${LINE:0:1} != "@" ]]; then
                IDX=$(( IDX + 1 ))
                LINES[$IDX]=$LINE
                continue
            elif [[ ${REFETCH:-false} == true ]]; then
                continue
            fi
            CACHE=$( echo -e ${LINE##*"="} )
            case $LINE in
                "@Cache[IPv4-Address]"*)
                    IP_ADDR_V4="$CACHE" ;;
                "@Cache[IPv6-Address]"*)
                    IP_ADDR_V6="$CACHE" ;;
                "@Cache[Invalid-Hosts]"*)
                    INV_HOSTS="${INV_HOSTS:-};$CACHE" ;;
                "@Cache[Record]"*)
                    RECORDS+=("$CACHE") ;;
            esac
        done < $LOG
    fi

    ## get deviding line
    function _deviding()
    {
        local LINE IDX RESULT
        for (( IDX = 1 ; IDX <= ($1-${#3})/2 ; IDX++ )); do
            LINE="${LINE:-}${2:0:1}"
        done
        RESULT="${LINE:-} $3 ${LINE:-}"
        echo ${RESULT:0:$1}
    }

    ## rewrite old log with length control
    local START END
    END=$(( IDX ))
    START=$(( END - LOG_LTH + 1 ))
    if [[ $START -le 0 ]]; then
        START=1
        echo -n "" > $LOG
    else
        echo $( _deviding 70 '-' '(discard above logs)' ) > $LOG
    fi
    for (( IDX = START ; IDX <= END ; IDX++ )); do
        [[ -n ${LINES[IDX]:-} ]] && echo ${LINES[IDX]:-} >> $LOG
    done

    ## write header for new log
    set +e
    LOG_TIME=$( eval ${LOG_TIME:-} 2>/dev/null )
    set -e
    echo $( _deviding 70 '=' "${LOG_TIME:-}" ) >> $LOG
}

function get_ip()
{
    local PATTERN POOL ARG
    if [[ $1 == "-v4" ]]; then
        ARG="-4"
        POOL=(
            "http://v4.ident.me"
            "https://ip4.nnev.de"
            "https://v4.ifconfig.co"
            "https://ipv4.icanhazip.com"
            "https://ipv4.wtfismyip.com/text"
        )
        PATTERN="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    elif [[ $1 == "-v6" ]]; then
        ARG="-6"
        POOL=(
            "http://v6.ident.me"
            "https://ip6.nnev.de"
            "https://v6.ifconfig.co"
            "https://ipv6.icanhazip.com"
            "https://ipv6.wtfismyip.com/text"
        )
        PATTERN="^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{1,4}$"
    else
        return
    fi
    
    ## get current ip from pool in random order
    local LTH=${#POOL[@]}
    local IDX=$(( $RANDOM % $LTH ))
    local TRY=0
    local RES
    while [[ $TRY -lt $LTH ]]; do
        TRY=$(( TRY + 1 ))
        set +e
        if [[ -n $( command -v wget ) ]]; then
            RES=$( wget -qO-  -t 1   -T 5 $ARG ${POOL[IDX]} )
        elif [[ -n $( command -v curl ) ]]; then
            RES=$( curl -s --retry 0 -m 5 $ARG ${POOL[IDX]} )
        fi
        set -e
        [[ $RES =~ $PATTERN ]] && break
        RES="NULL"
        IDX=$(( IDX + 1 ))
        [[ $IDX -ge $LTH ]] && IDX=$(( IDX - LTH ))
    done
    
    if [[ $ARG == "-4" ]]; then
        if [[ ${RES:=NULL} != ${IP_ADDR_V4:=NULL} ]]; then
            echo "IPv4 address changed to {$RES}" >> $LOG
        fi
        IP_ADDR_V4=$RES
    else
        if [[ ${RES:=NULL} != ${IP_ADDR_V6:=NULL} ]]; then
            echo "IPv6 address changed to {$RES}" >> $LOG
        fi
        IP_ADDR_V6=$RES
    fi
}

function fetch_records()
{
    FUNC_RETURN=""
    local DOMAIN="$1"

    ## fetch records list request
    ## https://www.namesilo.com/api-reference#dns/dns-list-records
    local REQ RES
    REQ="https://www.namesilo.com/api/dnsListRecords"
    REQ="$REQ?version=1&type=xml&key=$APIKEY&domain=$DOMAIN"
    set +e
    $( ${REQ_INTERVAL:-} 1>/dev/null 2>/dev/null )
    if [[ -n $( command -v wget ) ]]; then
        RES=$( wget -qO-  -t 2   -T 20 $REQ )
    elif [[ -n $( command -v curl ) ]]; then
        RES=$( curl -s --retry 1 -m 20 $REQ )
    fi
    set -e

    ## parse list response
    local ID TYPE HOST VALUE TTL FAIL
    local CODE DETAIL FETCHED=()
    local TAG TEXT XPATH="" IFS=\>
    while read -d \< TAG TEXT; do
        if [[ ${TAG:0:1} == "?" ]]; then     ## xml declare
            continue
        elif [[ ${TAG:0:1} == "/" ]]; then   ## node end
            if [[ $XPATH == "//namesilo/reply/resource_record" ]]; then
                FETCHED+=("${ID:-}|${TYPE:-}|${HOST:-}|${VALUE:-}|${TTL:-}|${FAIL:-0}")
                unset ID TYPE HOST VALUE TTL FAIL
            fi
            XPATH=${XPATH%$TAG}
        else                                 ## node start
            XPATH="$XPATH/$TAG"
            case $XPATH in
                "//namesilo/reply/code")
                    CODE=$TEXT ;;
                "//namesilo/reply/detail")
                    DETAIL=$TEXT ;;
                "//namesilo/reply/resource_record/record_id")
                    ID=$TEXT ;;
                "//namesilo/reply/resource_record/type")
                    TYPE=$TEXT ;;
                "//namesilo/reply/resource_record/host")
                    HOST=$TEXT ;;
                "//namesilo/reply/resource_record/value")
                    VALUE=$TEXT ;;
                "//namesilo/reply/resource_record/ttl")
                    TTL=$TEXT ;;
            esac
        fi
    done <<< "$RES"
    RECORDS+=(${FETCHED[@]:-})
    [[ ${CODE:=000} -eq 000 ]] && DETAIL="network communication failed"
    echo "Fetch ${#FETCHED[@]} record(s) of [$DOMAIN]: ($CODE) ${DETAIL:-}" >> $LOG
    FUNC_RETURN="$CODE"
}

function update_record()
{
    FUNC_RETURN=""
    ## parse record info
    local ID TYPE HOST VALUE TTL FAIL
    local DOMAIN SUBDOMAIN VAR
    VAR=(${1//|/ })
    ID=${VAR[0]:-}
    TYPE=${VAR[1]:-}
    HOST=${VAR[2]:-}
    VALUE=${VAR[3]:-NULL}
    TTL=${VAR[4]:-}
    FAIL=${VAR[5]:-0}
    VAR=(${HOST//./ })
    if [[ ${#VAR[@]} -le 2 ]]; then
        DOMAIN="$HOST"
        SUBDOMAIN=""
    else
        DOMAIN="${VAR[-2]}.${VAR[-1]}"
        SUBDOMAIN="${HOST%.$DOMAIN}"
    fi

    ## update check
    local IP_ADDR CHECK
    if [[ $TYPE == "A" ]]; then
        IP_ADDR=${IP_ADDR_V4:-NULL}
        [[ $IP_ADDR == "NULL" ]] && CHECK="IPv4 address is unknown"
    elif [[ $TYPE == "AAAA" ]]; then
        IP_ADDR=${IP_ADDR_V6:-NULL}
        [[ $IP_ADDR == "NULL" ]] && CHECK="IPv6 address is unknown"
    else
        FAIL=$(( FAIL + 1 ))
        CHECK="Record type [$TYPE] is not supported"
    fi
    if [[ -n ${CHECK:-} ]]; then
        unset
    elif [[ ! $ID =~ ^[0-9a-fA-F]{32}$ ]]; then
        FAIL=$(( FAIL + 1 ))
        CHECK="Format of record ID [$ID] is invalid"
    elif [[ ${IP_ADDR:-NULL} == $VALUE ]]; then
        [[ ${FORCE:-false} != true ]] && CHECK="IP is not changed"
    fi
    if [[ -n ${CHECK:-} ]]; then
        echo "Update record [$TYPE//$HOST//${ID:0:4}]: $CHECK" >> $LOG
        FUNC_RETURN="$ID|$TYPE|$HOST|$VALUE|$TTL|$FAIL"
        return
    fi

    ## update record request
    ## https://www.namesilo.com/api-reference#dns/dns-update-record
    local REQ RES
    REQ="https://www.namesilo.com/api/dnsUpdateRecord"
    REQ="$REQ?version=1&type=xml&key=$APIKEY&domain=$DOMAIN"
    REQ="$REQ&rrid=$ID&rrhost=$SUBDOMAIN&rrvalue=$IP_ADDR&rrttl=${TTL:=3600}"
    set +e
    $( ${REQ_INTERVAL:-} 1>/dev/null 2>/dev/null )
    if [[ -n $( command -v wget ) ]]; then
        RES=$( wget -qO-  -t 2   -T 10 $REQ )
    elif [[ -n $( command -v curl ) ]]; then
        RES=$( curl -s --retry 1 -m 10 $REQ )
    fi
    set -e

    ## parse result response
    local CODE DETAIL NEW_ID
    local TAG TEXT XPATH="" IFS=\>
    while read -d \< TAG TEXT; do
        if [[ ${TAG:0:1} == "?" ]]; then     ## xml declare
            continue
        elif [[ ${TAG:0:1} == "/" ]]; then   ## node end
            XPATH=${XPATH%$TAG}
        else                                 ## node start
            XPATH="${XPATH}/${TAG}"
            case ${XPATH} in
                "//namesilo/reply/code")
                    CODE=$TEXT ;;
                "//namesilo/reply/detail")
                    DETAIL=$TEXT ;;
                "//namesilo/reply/record_id")
                    NEW_ID=$TEXT ;;
            esac
        fi
    done <<< "$RES"
    [[ ${CODE:=000} -eq 000 ]] && DETAIL="network communication failed"
    [[ ${CODE:=000} -eq 300 ]] && DETAIL="$DETAIL [${ID:0:4}=>${NEW_ID:0:4}]"
    echo "Update record [$TYPE//$HOST//${ID:0:4}]: ($CODE) ${DETAIL:-}" >> $LOG
    if [[ $CODE -eq 300 ]]; then
        ID="$NEW_ID"
        VALUE="$IP_ADDR"
        FAIL=0
    else
        FAIL=$(( FAIL + 1 ))
    fi
    FUNC_RETURN="$ID|$TYPE|$HOST|$VALUE|$TTL|$FAIL"
}

function main()
{
    load_log
    if [[ ! ${APIKEY:-} =~ ^[0-9a-f]{24}$ || -z ${HOSTS[@]} ]]; then
        echo "No valid API key or host" >> $LOG
        exit 1
    fi
    get_ip -v4
    get_ip -v6
    local HOST DOMAIN RECORD VAR FAIL ID CHECKED
    declare -A STATUS
    
    ## initialize host status dictionary
    for HOST in "${HOSTS[@]:-}"; do
        [[ -z $HOST ]] && continue
        VAR=(${HOST//./ })
        [[ ${#VAR[@]} -lt 2 ]] && continue
        if [[ ";${INV_HOSTS:-};" == *";$HOST;"* ]]; then
            STATUS[$HOST]="<disabled>"
        else
            STATUS[$HOST]="<init>"
        fi
    done

    ## check records from log and discard invalid ones
    CHECKED=()
    for RECORD in "${RECORDS[@]:-}"; do
        [[ -z $RECORD ]] && continue
        VAR=(${RECORD//|/ })
        HOST=${VAR[2]:-}
        FAIL=${VAR[5]:-0}
        if [[ -z $HOST || -z ${STATUS[$HOST]:-} ]]; then
            continue    ## no fitting host
        elif [[ ${STATUS[$HOST]} == "<disabled>" ]]; then
            continue    ## the host has been disabled
        elif [[ $FAIL -gt $REQ_RETRY ]]; then
            ## the record has too many failed requests
            STATUS[$HOST]="<suspended>"
            continue
        elif [[ ${STATUS[$HOST]} == "<init>" ]]; then
            STATUS[$HOST]="<matched>"
        fi
        CHECKED+=("$RECORD")
    done
    RECORDS=(${CHECKED[@]:-})

    ## fetch record info for hosts with issues
    local FETCHED_DOMAIN=""
    for HOST in "${!STATUS[@]}"; do
        [[ ${STATUS[$HOST]} == "<disabled>" ]] && continue
        [[ ${STATUS[$HOST]} == "<matched>" ]] && continue
        VAR=(${HOST//./ })
        DOMAIN="${VAR[-2]}.${VAR[-1]}"
        if [[ "|$FETCHED_DOMAIN|" != *"|$DOMAIN|"* ]]; then
            fetch_records $DOMAIN
            if [[ ${FUNC_RETURN:-000} -ne 000 ]]; then
                FETCHED_DOMAIN="$FETCHED_DOMAIN|$DOMAIN"
            fi
        fi
        STATUS[$HOST]="<init>"
    done

    ## update ip for valid records
    CHECKED=()
    for RECORD in "${RECORDS[@]:-}"; do
        [[ -z $RECORD ]] && continue
        VAR=(${RECORD//|/ })
        ID=${VAR[0]:-}
        HOST=${VAR[2]:-}
        if [[ -z $ID || " ${CHECKED[@]:-}" == *" $ID|"* ]]; then
            continue    ## duplicated record
        elif [[ -z $HOST || -z ${STATUS[$HOST]:-} ]]; then
            continue    ## no fitting host
        elif [[ ${STATUS[$HOST]} == "<disabled>" ]]; then
            continue    ## the host has been disabled
        fi
        update_record $RECORD
        if [[ -n $FUNC_RETURN ]]; then
            CHECKED+=("$FUNC_RETURN")
            STATUS[$HOST]="<matched>"
        fi
    done
    RECORDS=(${CHECKED[@]:-})

    ## collect invalid hosts
    INV_HOSTS=""
    for HOST in "${!STATUS[@]}"; do
        [[ ${STATUS[$HOST]} == "<matched>" ]] && continue
        VAR=(${HOST//./ })
        DOMAIN="${VAR[-2]}.${VAR[-1]}"
        if [[ ${STATUS[$HOST]} == "<disabled>" ]]; then
            INV_HOSTS="$INV_HOSTS;$HOST"
        elif [[ "|$FETCHED_DOMAIN|" == *"|$DOMAIN|"* ]]; then
            STATUS[$HOST]="<disabled>"
            INV_HOSTS="$INV_HOSTS;$HOST"
        fi
    done

    ## print records for next running
    echo "@Cache[IPv4-Address]=${IP_ADDR_V4:-NULL}" >> $LOG
    echo "@Cache[IPv6-Address]=${IP_ADDR_V6:-NULL}" >> $LOG
    if [[ -n ${INV_HOSTS:-} ]]; then
        echo "@Cache[Invalid-Hosts]=${INV_HOSTS#;}" >> $LOG
    fi
    for RECORD in "${RECORDS[@]:-}"; do
        [[ -n $RECORD ]] && echo "@Cache[Record]=$RECORD" >> $LOG
    done
}

parse_args $*
main
