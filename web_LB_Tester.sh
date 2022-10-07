#!/bin/bash
# cybergavin (https://github.com/cybergavin)
# QAD script to test web traffic load distribution across sites from an end-user perspective
# The web application must deliver a unique identifier on its web page for each site
#
####################################################################################################################
gslb_url=$1
site1_check=$2
site2_check=$3
num_iterations=${4:-50}
if [ -z "$gslb_url" -o -z "$site1_check" -o -z "$site2_check" ]; then
	echo -e "\nMissing arguments!\nUSAGE: bash lbTest.sh <site_URL> <site1_regex> <site2_regex> [number of iterations]\n\n"
	exit 100
fi
count=1
site1_count=1
site1_total_time=0
site2_count=1
site2_total_time=0
while [ $count -le $num_iterations ]
do
	curl_resp=`curl -k -m5 -w "\n%{time_total}\n" -s $gslb_url 2>/dev/null`
	curl_time=$(echo $curl_resp | awk '{print $NF}') 
	site_time=$(bc <<< "scale=2.2; $curl_time") 
	[[ -n "`echo $curl_resp | grep -i \"$site1_check\"`" ]] && site1_count=$(( site1_count + 1 )) && site1_total_time=$(bc <<< "scale=2.2; $site1_total_time + $site_time")
	[[ -n "`echo $curl_resp | grep -i \"$site2_check\"`" ]] && site2_count=$(( site2_count + 1 )) && site2_total_time=$(bc <<< "scale=2.2; $site2_total_time + $site_time")
	count=$(( count + 1 ))
done
echo -e "\nGSLB URL TESTED = ${gslb_url}"
echo -e "\nTOTAL NUMBER OF ITERATIONS = $(( count - 1 ))"
site1_pct_hits=$(bc <<< "scale=2.2; ($site1_count - 1) * 100 / ($count - 1)")
[ $site1_count -gt 1 ] && site1_avg_time=$(bc <<< "scale=2.2; $site1_total_time / ($site1_count - 1)") || site1_avg_time=0
site2_pct_hits=$(bc <<< "scale=2.2; ($site2_count - 1) * 100 / ($count - 1)")
[ $site2_count -gt 1 ] && site2_avg_time=$(bc <<< "scale=2.2; $site2_total_time / ($site2_count - 1)") || site2_avg_time=0
#echo $site1_total_time $site2_total_time
echo -e "\nSITE 1 (${site1_check}) HITS = $(( site1_count - 1 )) (${site1_pct_hits}%) | SITE 1 AVG. TIME = ${site1_avg_time} seconds"
echo -e "\nSITE 2 (${site2_check}) HITS = $(( site2_count - 1 )) (${site2_pct_hits}%) | SITE 2 AVG. TIME = ${site2_avg_time} seconds\n\n"
