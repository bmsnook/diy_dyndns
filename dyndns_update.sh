#!/bin/bash

mydomain="yourdomain.dom"
myhostname="gateway"
host1="host1"
host2="host2"
logdest="local7.info"
gdapikey="$(/usr/local/bin/aws secretsmanager get-secret-value \
            --secret-id prod/dns/godaddy \
            --query SecretString | \
                jq -r '[.dns_api_key, .dns_api_secret] | join(":")'
           )"

datestamp_msg() {
    DATETIME="$(date "+%Y-%m-%d %H:%M:%S")"
    printf "${DATETIME} DNS-UPDATE: ${@}\n"
}
cur_ip="$(/usr/bin/curl -s "https://api.ipify.org")"
dnsdata="$(/usr/bin/curl -s \
            -X GET \
            -H "Authorization: sso-key ${gdapikey}" \
            "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}"
          )"

#dns_ip="$(echo $dnsdata | cut -d ',' -f 1 | tr -d '"' | cut -d ":" -f 2)"
#dns_ip="$(echo $dnsdata | awk -F'[:,]' '{ip=gensub("[][{}\"]","","g",$2);print ip}')"
#dns_ip="$(echo $dnsdata | awk -F'[:,]' '{ip=gensub("\"","","g",$2);print ip}')"
#dns_ip="$(echo $dnsdata | awk -F'[:,]' '{gsub(/"/,"");print $2}')"
dns_ip="$(printf ${dnsdata} | jq -r '.[].data')"
#echo "`date '+%Y-%m-%d %H:%M:%S'` - Current External IP is $cur_ip, GoDaddy DNS IP is $dns_ip"
datestamp_msg "hostname ${myhostname}.${mydomain} current IP: ${cur_ip} and DNS IP: ${dns_ip}"

if [ "$dns_ip" != "$cur_ip" -a "$cur_ip" != "" ]; then
    printf "IP has changed! Updating GoDaddy from \"${dns_ip}\" to \"${cur_ip}\"\n"
    ## gateway
    /usr/bin/curl -s -X PUT \
        "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}" \
        -H "Authorization: sso-key ${gdapikey}" \
        -H "Content-Type: application/json" \
        -d "[{\"data\": \"${cur_ip}\"}]" && \
    logger -p $logdest "SUCCESS: Changed IP for ${myhostname}.${mydomain} from \"${dns_ip}\" to \"${cur_ip}\"" || \
    logger -p $logdest "FAILURE: ERROR updating ${myhostname}.${mydomain} from \"${dns_ip}\" to \"${cur_ip}\""
    ## host1
    /usr/bin/curl -s -X PUT \
        "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${host1}" \
        -H "Authorization: sso-key ${gdapikey}" \
        -H "Content-Type: application/json" \
        -d "[{\"data\": \"${cur_ip}\"}]" && \
    logger -p $logdest "SUCCESS: Changed IP for ${host1}.${mydomain} from \"${dns_ip}\" to \"${cur_ip}\"" || \
    logger -p $logdest "FAILURE: ERROR updating ${host1}.${mydomain} from \"${dns_ip}\" to \"${cur_ip}\""
    ## host2
    /usr/bin/curl -s -X PUT \
        "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${host2}" \
        -H "Authorization: sso-key ${gdapikey}" \
        -H "Content-Type: application/json" \
        -d "[{\"data\": \"${cur_ip}\"}]" && \
    logger -p $logdest "SUCCESS: Changed IP for ${host2}.${mydomain} from \"${dns_ip}\" to \"${cur_ip}\"" || \
    logger -p $logdest "FAILURE: ERROR updating ${host2}.${mydomain} from \"${dns_ip}\" to \"${cur_ip}\""
fi

