#!/bin/bash
# cybergavin (https://github.com/cybergavin)
# webTDT => Web Traffic Distribution Tester
# QAD script to test web traffic load distribution across  2 sites from an end-user perspective
# The web application must deliver a unique identifier (site 1 regex and site2 regex) on its web page for each site in order to determine traffic distribution
# May also be used to test a single URL with only the -u option (default #iterations is 50) 
#
####################################################################################################################
function usage
{
	echo -e "\nMissing arguments!\nUSAGE: bash $(basename $0) -u <site_URL> [-1 <site1_regex> -2 <site2_regex> -n number of iterations]\n\n"
	exit 100
}
#
# Parse Input
#
while getopts ":u:1:2:n:o:" opt; do
        case $opt in
                u)      gslb_url=$OPTARG
                        ;;
                1)     site1_check=$OPTARG
                        ;;
                2)     site2_check=$OPTARG
                        ;;
                n)      num_iterations=$OPTARG
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
#
# Validate input paramaters
#
: ${gslb_url:?Option -u requires an argument.}
#
# Main
#
num_iterations=${num_iterations:-50}
count=1
site1_count=0
site1_total_time=0
site2_count=0
site2_total_time=0
site_count=0
site_total_time=0
invalid_hits=0
while [ $count -le $num_iterations ]
do
	curl_resp=`curl -k -m5 -w "\n%{http_code}\n%{time_total}\n" -s $gslb_url 2>/dev/null`
	curl_time=$(echo $curl_resp | awk '{print $NF}') 
	curl_resp_code=$(echo $curl_resp | awk '{print $(NF-1)}') 
	site_time=$(bc <<< "scale=2.2; $curl_time") 
	if [ $curl_resp_code == 200 ]; then
		if [ -n "$site1_check" -a -n "`echo $curl_resp | grep -i \"$site1_check\"`" ]; then
		   site1_count=$(( site1_count + 1 ))
		   site1_total_time=$(bc <<< "scale=2.2; $site1_total_time + $site_time")
		elif [ -n "$site2_check" -a -n "`echo $curl_resp | grep -i \"$site2_check\"`" ]; then
		   site2_count=$(( site2_count + 1 ))
		   site2_total_time=$(bc <<< "scale=2.2; $site2_total_time + $site_time")
	        elif [ -z "$site1_check" -a -z "$site2_check" ]; then
		   site_count=$(( site_count + 1 ))
		   site_total_time=$(bc <<< "scale=2.2; $site_total_time + $site_time")
		fi
	else
		invalid_hits=$(( invalid_hits + 1 ))
	fi
	count=$(( count + 1 ))
done
echo -e "\n*************************************************"
echo -e "\nGSLB URL TESTED = ${gslb_url}"
echo -e "\nTOTAL NUMBER OF ITERATIONS = $(( count - 1 ))"
echo -e "\nTOTAL NUMBER OF INVALID HITS (NOT HTTP 200) = $invalid_hits"
if [ -n "$site1_check" ]; then
	site1_pct_hits=$(bc <<< "scale=2.2; $site1_count * 100 / ($count - 1)")
	[ $site1_count -gt 1 ] && site1_avg_time=$(bc <<< "scale=2.2; $site1_total_time / $site1_count") || site1_avg_time=0
	echo -e "\nSITE 1 (${site1_check}) HITS = $site1_count (${site1_pct_hits}%) | SITE 1 AVG. TIME = ${site1_avg_time} seconds"
fi
if [ -n "$site2_check" ]; then
	site2_pct_hits=$(bc <<< "scale=2.2; $site2_count * 100 / ($count - 1)")
	[ $site2_count -gt 1 ] && site2_avg_time=$(bc <<< "scale=2.2; $site2_total_time / $site2_count") || site2_avg_time=0
	echo -e "\nSITE 2 (${site2_check}) HITS = $site2_count (${site2_pct_hits}%) | SITE 2 AVG. TIME = ${site2_avg_time} seconds"
fi
if [ -z "$site1_check" -a -z "$site2_check" ]; then
	site_pct_hits=$(bc <<< "scale=2.2; $site_count * 100 / ($count - 1)")
	[ $site_count -gt 1 ] && site_avg_time=$(bc <<< "scale=2.2; $site_total_time / $site_count") || site_avg_time=0
	echo -e "\nTOTAL VALID SITE HITS = $site_count (${site_pct_hits}%) | SITE AVG. TIME = ${site_avg_time} seconds"
fi
echo -e "\n*************************************************"
echo -e "\nCSV OUTPUT\n----------\n"
echo "GSLB_URL,NUM_ITERATIONS,SITE_HITS,SITE_AVG_TIME,SITE1_HITS,SITE1_HITS_PCT,SITE1_AVG_TIME,SITE2_HITS,SITE2_HITS_PCT,SITE2_AVG_TIME,INVALID_HITS"
echo "${gslb_url},${num_iterations},${site_count},${site_avg_time},${site1_count},${site1_pct_hits},${site1_avg_time},${site2_count},${site2_pct_hits},${site2_avg_time},${invalid_hits}"
