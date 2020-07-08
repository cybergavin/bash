#!/bin/bash
# cybergavin
# 7th July 2020
# Add DNS A records in bulk to a DNS zone using dnsperf
# Pre-requisite: dnsperf installed and somewhere in $PATH
##########################################################
#
# Determine Script Location
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
if [ $# -eq 0 ]; then
   printf "ERROR : Invalid script usage.\nUSAGE: ${SCRIPT_LOCATION}/${SCRIPT_NAME} -s <dns server> -z <dns zone> -n <number of A records to add>\n\n"
   exit 1
else
 while getopts ":s:z:n:" opt
  do
   case $opt in
         s )  myserver=${OPTARG}
              ;;
         z )  myzone=${OPTARG}
              ;;
         n )  myrrnum=${OPTARG}
              ;;
         : )  printf "\n$0: Missing argument for -$OPTARG option\n\n"
              exit 2
              ;;
         \? ) printf "ERROR : Invalid script usage.\nUSAGE: ${SCRIPT_LOCATION}/${SCRIPT_NAME}  -s <dns server> -z <dns zone> -n <number of A records to add>\n\n"
              exit 1
              ;;
     esac
   done
 shift $(($OPTIND - 1))
fi
count=1
datafile=${SCRIPT_NAME%%.*}.txt
cat /dev/null > $datafile
while [ $count -le $myrrnum ]
do
cat<<EOF >> $datafile
$myzone
add `head /dev/urandom | tr -dc A-Za-z0-9 | head -c5` 60 A 10.$(( $RANDOM % 254 )).$(( $RANDOM % 254 )).$(( $RANDOM % 254 ))
send
EOF
count=$(( count + 1 ))
done
dnsperf -s $myserver -d $datafile -u