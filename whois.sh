#!/bin/bash
# cybergavin - 14-OCT-2020
# This script accepts a single-column list of public IP addresses and uses the API service at ip-api.com to determine the organizations that own the IP addresses
# The API service is rate limited to 15 requests per minute.
# Requirements : bash, curl, jq
#
ipfile="/iplist"
if [ ! -s $ipfile ]; then
cat<<EOF

Input file (iplist) is empty or not found!

USAGE: docker run -v <localhost file path>:/iplist -it cg_whois

where <localhost file path> = Absolute file path of the file containing the list of IP addresses to be looked up (WHOIS)

EOF
exit 100
fi
mapfile=ip-whois; cat /dev/null > $mapfile
###############################################################
# Main
###############################################################
#
# ip-api accepts batches of 100 IPs at a time for whois lookups
#
num_ips=`wc -l $ipfile | cut -d' ' -f1`
last_batch=$(( num_ips % 100 ))
if [ $last_batch -eq 0 ]; then
        num_batches=$(( num_ips / 100 ))
else
        num_batches=$(( (num_ips / 100) + 1 ))
fi
#
# For each batch, generate the require JSON data, make the API call and process the response
#
bn=1
while [ $bn -le $num_batches ]
        do
                if [ $bn -lt $num_batches ]; then
                        head -$(( bn * 100 )) $ipfile | tail -100 | sed 's/^/"/g;s/$/",/g;$s/,/\n]/;1 s/"/[\n"/' > ipbatch${bn}.json
                        curl -X POST http://ip-api.com/batch?fields=org -d @ipbatch${bn}.json 2>/dev/null | jq '.[] |.org' > ipbatch${bn}.whois
                        cat ipbatch${bn}.json | jq '.[]' > ipbatch${bn}.ip
                        if [ `wc -l ipbatch${bn}.ip | cut -d' ' -f1` -eq `wc -l ipbatch${bn}.whois | cut -d' ' -f1` ]; then
                                paste ipbatch${bn}.ip ipbatch${bn}.whois | column -s $'\t' -t >> $mapfile
                        else
                                echo "ERROR : Unmatched #lines in ipbatch${bn}.whois and ipbatch${bn}.ip"
                        fi
                        if [ $(( bn % 15 )) -eq 0 ]; then
                                sleep 65
                        fi
                        bn=$(( bn + 1 ))
                else
                        tail -${last_batch} $ipfile | sed 's/^/"/g;s/$/",/g;$s/,/\n]/;1 s/"/[\n"/' > ipbatch${bn}.json
                        curl -X POST http://ip-api.com/batch?fields=org -d @ipbatch${bn}.json 2>/dev/null | jq '.[] |.org' > ipbatch${bn}.whois
                        cat ipbatch${bn}.json | jq '.[]' > ipbatch${bn}.ip
                        if [ `wc -l ipbatch${bn}.ip | cut -d' ' -f1` -eq `wc -l ipbatch${bn}.whois | cut -d' ' -f1` ]; then
                                paste ipbatch${bn}.ip ipbatch${bn}.whois | column -s $'\t' -t >> $mapfile
                        else
                                echo "ERROR : Unmatched #lines in ipbatch${bn}.whois and ipbatch${bn}.ip"
                        fi
                        bn=$(( bn + 1 ))
                fi
        done
cat $mapfile