#!/bin/bash
# Author       : mrkips (Cybergavin) 
# Date Created : 18th March 2017
# Description  : This is a utility script that provisions mountpoints (using LVM) when hard disks are added to VMs.
#                Tested with RHEL 7 and CentOS 8.
#
#~~~~~~~~~~~~~~~~~~
# VERSION HISTORY
#~~~~~~~~~~~~~~~~~~
#  v1.0  | 18-Mar-2017  | First Version
#
#######################################################################################################
#
# Redirect unhandled stderr
#
exec 2> /var/log/LVM_addDisk.err
#
# Only allow execution with root privileges
#
if [ "$(id -u)" != "0" ]; then
   printf "\nThis script must be executed with root privileges. Exiting...\n"
   exit  1
fi
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
if [ ! -f ${SCRIPT_LOCATION}/${SCRIPT_NAME} ]; then
   printf "\n`date '+%Y%m%d_%H%M'` : ERROR : Could not detect script location and/or name. Check and test script. Exiting...\n"
   exit 1
fi
function helpme
{
cat<<EOF

~~~~~~~~~~~~~~~~~~~~~~ LVM_addDisk USAGE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

$(echo -e "${YELLOW}USE CASE 1: A single hard disk added to the VM.${NC}")

$(echo -e "${GREEN}./${SCRIPT_NAME} -n <name of mount point>${NC}")
Example: For a single hard disk added to a VM (presented as any device file /dev/sd?):
         ./LVM_addDisk.sh -n log

$(echo -e "${YELLOW}USE CASE 2: Multiple hard disks added to the VM.${NC}")

$(echo -e "${GREEN}./${SCRIPT_NAME} -n <name of mount point> -m <mount point>${NC}")
Example: For multiple hard disks added to a VM and presented as device files /dev/sdb and /dev/sdc:
         ./LVM_addDisk.sh -n app -m /dev/sdb
         ./LVM_addDisk.sh -n log -m /dev/sdc

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EOF
exit 100
}
function lvmCreate
{
   mp_name=$1
   mp=$2
   appcount=0
   pvcreate $mp
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   lvi=$(vgdisplay | awk '/VG Name/{print $NF}' | awk -F'vg0' '{print $2}' | sort -n | tail -1)
   myvi=$(( lvi + 1 ))
   myvg=vg0${myvi}
   vgcreate $myvg $mp
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   mype=`vgdisplay $myvg | grep "Total PE" | awk '{print $3}'`
   lvcreate -l $mype $myvg -n $mp_name
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   vgchange -aly $myvg
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   mkfs.xfs /dev/mapper/${myvg}-${mp_name}
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   mkdir /${mp_name}
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   echo "/dev/mapper/${myvg}-${mp_name}    /${mp_name}                    xfs     defaults,nodev,nosuid        0 0" >> /etc/fstab
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   mount /${mp_name}
   [[ $? -ne 0 ]] && appcount=$(( appcount + 1 ))
   if [ $appcount -eq 0 ]; then
      echo -e "${GREEN}INFO${NC}: Provisioned unused storage device $mp as /${MP_NAME}"
   else
      echo -e "${RED}ERROR${NC}: Failed to provision unused storage device $mp."
   fi
}
#
# Main
#
clear
#
# Variables
#
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color
#
# Parse input parameters
#
if [ $# -eq 0 ]; then
   helpme
fi
while getopts ":n:m:h" opt; do
        case $opt in
                n)      MP_NAME=$OPTARG
                        ;;
                m)      MP=$OPTARG
                        ;;
                h)      helpme
                        ;;
                \?)     echo "Invalid option: -$OPTARG"
                        helpme
                        ;;
                :)      echo "Option -$OPTARG requires an argument."
                        helpme
                        ;;
        esac
done
shift $((OPTIND-1))
#
# Device File Validation
#
d_count=0
for d in `ls /dev/sd[b-z]`
do
  if [ -z "`pvdisplay | grep $d`" ]; then
     d_count=$(( d_count + 1 ))
     d_name=$d
  fi
done
#
# Provision mount point
#
if [ $d_count -eq 1 -a -n "${MP_NAME}" ]; then
   echo -e "${GREEN}INFO${NC}: Found unused storage device $d_name. Provisioning /${MP_NAME}..."
   lvmCreate ${MP_NAME} $d_name
elif [ $d_count -gt 1 -a -n "${MP_NAME}" -a -n "${MP}" ]; then
   echo -e "${GREEN}INFO${NC}: Provisioning ${MP} as /${MP_NAME}..."
   lvmCreate ${MP_NAME} ${MP}
elif [ $d_count -eq 0 ]; then
   echo -e "${YELLOW}WARNING${NC}: No unused storage devices (hard disks) found. Exiting...."
else
   helpme
fi
