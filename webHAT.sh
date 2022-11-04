#!/bin/bash
# cybergavin (https://github.com/cybergavin)
# webHAT => Web High Availability Tester
# QAD script to check ad hoc availability (HTTP 200) of a web service/application 
# Example use-case: Test website failover
#
####################################################################################################################
trap 'logResult && exit 200' SIGTERM SIGINT SIGKILL
function usage
{
	echo -e "\nMissing arguments!\nUSAGE: bash $(basename $0) -u <gslb_url> -n <number of iterations> -b <string to match response body>\n\n"
    echo -e "If number of iterations is not specified, then the script runs indefinitely until you kill it.\n\n"
	exit 100
}
function checkWeb
{
    curl_resp=`curl -k -m1 -w "\n%{http_code}\n" -s $1 2>/dev/null`
	curl_resp_code=$(echo $curl_resp | awk '{print $NF}') 
    curl_resp_body=$(echo $curl_resp | grep "${body_check}")
}
function logResult
{
    echo -e "\n"
    printf "*%.0s" {1..75}
    echo -e "\nDURATION ~ $count seconds | DOWNTIME ~ $(( count - valid_hits )) seconds | AVAILABILITY ~ $(( valid_hits * 100/count )) %"
    printf "*%.0s" {1..75}
    echo -e "\nCheck data in ${csv_file} to correlate downtime.\n"
}
if [ $# -eq 0 ]; then
    usage
fi
#
# Parse Input
#
while getopts ":u:n:b:" opt; do
        case $opt in
                u)      gslb_url=$OPTARG
                        ;;
                n)      num_iterations=$OPTARG
                        ;;
                b)      body_check=$OPTARG
                        ;;
                \?)     echo -e "\nInvalid option: -$OPTARG"
                        usage
                        ;;
                :)      echo -e "\nOption -$OPTARG requires an argument."
                        usage
                        ;;
        esac
done
if ((OPTIND == 1)); then
	usage
fi
shift $((OPTIND-1))
num_iterations=${num_iterations:-20}
#
# Main
#
csv_file=$(basename "${0%.*}.csv")
echo "DATE,TIME,VALID_HIT" > $csv_file
count=0
valid_hits=0
echo -n "|" # Reference for up (-) and down(_)
if [ -n "$num_iterations" ]; then
    while [ $count -lt $num_iterations ]
        do
            checkWeb $gslb_url
            if [ $curl_resp_code == 200 -a -n "$curl_resp_body" ]; then
                valid_hits=$(( valid_hits + 1 ))
                echo -n "-"
                echo "`date '+%Y%m%d'`,`date '+%H:%M:%S'`,1" >> $csv_file
            else
                echo -n "_"
                echo "`date '+%Y%m%d'`,`date '+%H:%M:%S'`,0" >> $csv_file
            fi
            count=$(( count + 1 ))
            [[ $(( count % 50 )) -eq 0 ]] && echo -e "\n"
            sleep 1
        done
else
    while [ true ]
        do
            checkWeb $gslb_url 
            if [ $curl_resp_code == 200 -a -n "$curl_resp_body" ]; then
                valid_hits=$(( valid_hits + 1 ))
                echo -n "-"
                echo "`date '+%Y%m%d'`,`date '+%H:%M:%S'`,1" >> $csv_file
            else
                echo -n "_"
                echo "`date '+%Y%m%d'`,`date '+%H:%M:%S'`,0" >> $csv_file
            fi
            count=$(( count + 1 ))
            [[ $(( count % 50 )) -eq 0 ]] && echo -e "\n"          
            sleep 1
        done
fi
logResult