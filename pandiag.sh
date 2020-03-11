# cybergavin - March 10th, 2020
# This script obtains diagnostic data for Palo Alto Networks Support to troubleshoot an existing issue, should it recur.
# ATTENTION: The PAN CLI commands were provided by PAN Support for execution via ttl (Tera Term) and have been ported to a shell script.
#            To be tested for at least a week with monitoring of resource utilization and checks for any adverse impact, before deployment on Production.
# Set up the following crontab for housekeeping:
# 0 * * * * find <dir> -type f -name "pandiag_2020*.txt" -mmin +120 | xargs -i gzip {}
# * * * * 0 find <dir> -type f -name "pandiag_2020*.txt.gz" -mtime +7 | xargs -i rm -f {}
###########################################################################################################################################################
#
# User-defined Variables
#
ro_user=pandiag                    # Read-only User with SSH key for SSH access to firewall
active_firewall=XX.XX.XX.XX        # Active firewall IP/FQDN
mon_freq=5                         # Monitoring frequency in seconds
#
# Determine Script Location and define directories
#
if [ -n "`dirname $0 | grep '^/'`" ]; then
   SCRIPT_LOCATION=`dirname $0`
elif [ -n "`dirname $0 | grep '^..'`" ]; then
     cd `dirname $0`
     SCRIPT_LOCATION=$PWD
     cd - > /dev/null
else
     SCRIPT_LOCATION=`echo ${PWD}/\`dirname $0\` | sed 's#\/\.$##g'`
fi
SCRIPT_NAME=`basename $0`
tdate=`date '+%Y%m%d%H'`
datafile=${SCRIPT_LOCATION}/${SCRIPT_NAME%%.*}_${tdate}.txt
#
# Main
#
while [ true ]
do
echo "===== `date` =====" >> $datafile
ssh ${ro_user}@${active_firewall}<<EOF >> $datafile
set cli pager off
set cli scripting-mode on
show counter global filter delta yes
show running resource-monitor ingress-backlogs
show running resource-monitor second last 10
exit
EOF
sleep $mon_freq
done