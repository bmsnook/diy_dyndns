#!/bin/bash

DDOMAIN="yourdomain.dom"
HOSTLIST="gateway host1 host2"
LOGDEST="local7.info"
CURLPATH="/usr/bin/curl"
CNX_IP="$("${CURLPATH}" -s "https://api.ipify.org")"
if [[ -z $CNX_IP ]]; then
    logger -p $LOGDEST "ERROR: could not get current connection IP"
    exit -1
fi

## NOTE: GoDaddy API returns JSON output; process to extract the IP.
##   TIMTOWTDI. Choose the last command unless you don't have 'jq' installed;
##   then choose the next last command
##     ... | cut -d ',' -f 1 | tr -d '"' | cut -d ":" -f 2
##     ... | awk -F'[:,]' '{ip=gensub("[][{}\"]","","g",$2);print ip}'
##     ... | awk -F'[:,]' '{ip=gensub("\"","","g",$2);print ip}'
##     ... | awk -F'[:,]' '{gsub(/"/,"");print $2}'
##     ... | jq -r '.[].data'
## 

GDAPIKEY="$(/usr/local/bin/aws secretsmanager get-secret-value \
            --secret-id prod/dns/godaddy \
            --query SecretString | \
                jq -r '[.dns_api_key, .dns_api_secret] | join(":")'
           )"

get_dns_ip() {
    DOMAIN=$1
    HOST=$2
    "${CURLPATH}" -s -X GET \
        -H "Authorization: sso-key ${GDAPIKEY}" \
        "https://api.godaddy.com/v1/domains/${DOMAIN}/records/A/${HOST}" |\
        jq -r '.[].data'
}
set_dns_ip() {
    DOMAIN=$1
    HOST=$2
    IP=$3
    "${CURLPATH}" -s -X PUT \
        "https://api.godaddy.com/v1/domains/${DOMAIN}/records/A/${HOST}" \
        -H "Authorization: sso-key ${GDAPIKEY}" \
        -H "Content-Type: application/json" \
        -d "[{\"data\": \"${IP}\"}]"
}
datestamp_msg() {
    DATETIME="$(date "+%Y-%m-%d %H:%M:%S")"
    printf "${DATETIME} DNS-UPDATE: ${@}\n"
}



for HHOST in $(printf "%s\n" ${HOSTLIST}); do
## debug
#datestamp_msg "hostname ${HHOST}.${DDOMAIN} current IP: ${CNX_IP} and DNS IP: ${DNS_IP}"
    DNS_IP="$(get_dns_ip ${DDOMAIN} ${HHOST})"

    if [ "$DNS_IP" != "$CNX_IP" -a "$CNX_IP" != "" ]; then
        printf "IP changed: updating DNS for \"${HHOST}.${DDOMAIN}\" from \"${DNS_IP}\" to \"${CNX_IP}\"\n"
        set_dns_ip ${DDOMAIN} ${HHOST} ${CNX_IP}
        sleep 5
        DNS_IP_AFTER="$(get_dns_ip ${DDOMAIN} ${HHOST})"
        if [ "$DNS_IP_AFTER" != "$CNX_IP" ]; then
            logger -p $LOGDEST "ERROR: change ${HHOST}.${DDOMAIN} from \"${DNS_IP}\" to \"${CNX_IP}\" FAILED"
        else
            logger -p $LOGDEST "SUCCESS: changed ${HHOST}.${DDOMAIN} from \"${DNS_IP}\" to \"${CNX_IP}\""
        fi
    fi
done

