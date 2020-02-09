#!/bin/bash
# Author       : mrkips (Cybergavin)
# Date Created : 4th April 2015
# Description  : This script accepts email requests for the health status of applications/hosts and sends
#                a response back to the requester with results from the Check_MK monitoring system.
#                Tested with Check_MK 1.2.8p9, Postfix 2.6.6, RHEL 6
#~~~~~~~~~~~~~~~~~~
# VERSION HISTORY
#~~~~~~~~~~~~~~~~~~
#  v1.0  | 04-Apr-2015  | First Version
#  v2.0  | 03-Dec-2015  | Created URLs for hosts pointing to their Check_MK pages
#
##############################################################################################
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
#
# Variables and Constants
#
LOGDIR=${SCRIPT_LOCATION}/logs
DATADIR=${SCRIPT_LOCATION}/data
WORKDIR=${SCRIPT_LOCATION}/work
TDATE=`date '+%Y%m%d'`
YMDATE=`date '+%Y%m'`
TIMESTAMP=`date '+%Y%m%d%H%M%S'`
SCRIPT_NAME=`basename $0`
OUTFILE=${SCRIPT_LOCATION}/${SCRIPT_NAME%%.*}.out
ERRFILE=${SCRIPT_LOCATION}/${SCRIPT_NAME%%.*}.err
LOGFILE=${LOGDIR}/${SCRIPT_NAME%%.*}_${YMDATE}.log
DATAFILE=${DATADIR}/${SCRIPT_NAME%%.*}_${YMDATE}.tsv
MAILFILE=${WORKDIR}/${SCRIPT_NAME%%.*}_$$.txt
HTMLFILE=${WORKDIR}/${SCRIPT_NAME%%.*}.html
CMKFILE=${WORKDIR}/${SCRIPT_NAME%%.*}.check
MUTTRC=${SCRIPT_LOCATION}/.muttrc
#
# Redirect stdout and stderr
#
exec 1> $OUTFILE
exec 2> $ERRFILE
#
# Validate directory structure
#
for mydir in $LOGDIR $DATADIR $WORKDIR
do
  if [ ! -d $mydir ]; then
     mkdir $mydir 2> /dev/null
     if [ $? -ne 0 ]; then
        echo "\n`date '+%Y%m%d_%H%M'` : CRITICAL : $mydir does not exist and cannot be created. Exiting..."
        exit 999
     fi
  fi
done
#####################################################################################
# Functions
#####################################################################################
#
# Parsing Functions
#
function parseMail
{
# Extract application(s) and host(s) - Try subject first (preferred) and then body
sender=`grep "^From:" $MAILFILE | awk '{print $NF}' | sed 's/<//g;s/>//g'`
# First try subject..
sub=`grep "^Subject:" $MAILFILE | grep -v Undeliverable | head -1`
if [ -n "$sub" ]; then
   myhosts=`echo $sub | awk -F':' '{ for (i=1;i<=NF;i++) if (tolower($i) ~ /host=/) print $i}' | cut -d'=' -f2`
   myapps=`echo $sub | awk -F':' '{ for (i=1;i<=NF;i++) if (tolower($i) ~ /app=/) print $i}' | cut -d'=' -f2`
fi
# ..And then try Body
if [ -n "`grep \"Content-Transfer-Encoding: quoted-printable\" $MAILFILE`" ]; then
   myhosts="${myhosts} `sed -n '/Content-Transfer-Encoding: quoted-printable/,/Content-Transfer-Encoding: quoted-printable/p' $MAILFILE | grep -i \"Host=\" | awk -F'=3D' '{print $2}'`"
   myapps="${myapps} `sed -n '/Content-Transfer-Encoding: quoted-printable/,/Content-Transfer-Encoding: quoted-printable/p' $MAILFILE | grep -i \"App=\" | awk -F'=3D' '{print $2}'`"
elif [ -n "`grep \"Content-Transfer-Encoding: base64\" $MAILFILE`" ]; then
   myhosts="${myhosts} `sed -n '/Content-Transfer-Encoding: base64/,/Content-Transfer-Encoding: base64/p' $MAILFILE | sed '/^Content/d;/^--/d;/^$/d' | base64 -d | grep -i \"Host=\" | awk -F'=' '{print $2}' | tr -d '\r'`"
   myapps="${myapps} `sed -n '/Content-Transfer-Encoding: base64/,/Content-Transfer-Encoding: base64/p' $MAILFILE | sed '/^Content/d;/^--/d;/^$/d' | base64 -d | grep -i \"App=\" | awk -F'=' '{print $2}' | tr -d '\r'`"
fi
}
#
# Validation Functions
#
function ignoreNDR
{
ndr=0
if [ -n "`grep \"^Subject: Undeliverable\" $MAILFILE`" ]; then
        ndr=1
fi
echo $ndr
}
function validateApp
{
cat<<EOF | /omd/sites/mysite/local/bin/unixcat /omd/sites/mysite/tmp/run/live
GET hostgroups
Columns: name
Filter: name = $1
EOF
}
function validateHost
{
cat<<EOF | /omd/sites/mysite/local/bin/unixcat /omd/sites/mysite/tmp/run/live
GET hosts
Columns: name
Filter: name = $1
EOF
}
#
# Data Query Functions
#
function lqlHS
{
# Determine count of services in various states for a given host using LQL
l_host=$1
cat<<EOF | /omd/sites/mysite/local/bin/unixcat /omd/sites/mysite/tmp/run/live
GET services
Filter: host_name = $l_host
Stats: state = 0
Stats: state = 1
Stats: state = 2
Stats: state = 3
EOF
}
function lqlAH
{
# Determine hosts belonging to a given hostgroup (application) using LQL
l_app=$1
cat<<EOF | /omd/sites/mysite/local/bin/unixcat /omd/sites/mysite/tmp/run/live
GET hostgroups
Columns: name members
Filter: name = $l_app
EOF
}
function lqlHG
{
# Determine list of hostgroups (applications) using LQL
cat<<EOF | /omd/sites/mysite/local/bin/unixcat /omd/sites/mysite/tmp/run/live
GET hostgroups
Columns: name
EOF
}
#
# HTML Build Functions
#
function htmlInit
{
# Initialize HTML file for email body - HEAD section with CSS
if [ -f $HTMLFILE ]; then
   rm $HTMLFILE
fi
cat <<EOF > $HTMLFILE
<html>
<head>
<style>
.datagrid1 table { border: 1px solid blue; border-collapse: collapse; text-align: center; width: 70%; font: normal 12px/150% Verdana, Arial, Helvetica, sans-serif; }
.datagrid2 table { border: 1px solid #960D06; border-collapse: collapse; text-align: left; width: 70%; font: normal 12px/150% Verdana, Arial, Helvetica, sans-serif; }
.datagrid1 td {border: 1px solid #588FEC;}
.datagrid2 td {border: 1px solid #960D06;}
.invalid {text-align: justify; font: normal 14px    /150% Verdana, Arial, Helvetica, sans-serif; }
.invalid table {text-align: justify; font: normal 12px    /150% Verdana, Arial, Helvetica, sans-serif;  border: 1px solid  blue; border-collapse: collapse;  width: 20%; }
.alt { background: #E1EEf4; color: #000000; }
.header1 { background: #E1EEf4; color: #588FEC; font-size: 14px; border: 1px solid blue; }
.header2 { background: #FBDEDC; color: #961511; font-size: 14px; border: 1px solid #960D06; }
.host1 { background: #588FEC; color: #FFFFFF; border: 1px solid blue; }
.host2 { background: #FBDEDC; color: #961511; border: 1px solid #960D06; }
.ok { background: #117C23; color: #FFFFFF; border: 1px solid blue; }
.warn { background: #EEF47C; color: #000000; border: 1px solid blue; }
.crit { background: #C51616; color: #FFFFFF; border: 1px solid blue; }
.unknown { background: #FBC138; color: #000000; border: 1px solid blue; }
</style>
</head>
<body>
EOF
}
function htmlHostStatus
{
# Start HTML Table for HOST HEALTH SUMMARY
cat <<EOF >> $HTMLFILE
<div class="datagrid1"><table>
<thead><tr><th class="header1" colspan="5">HOST HEALTH SUMMARY</th></thead>
<thead><tr><th class="host1" width="20%">HOST</th><th class="ok" width="10%">OK</th><th class="warn" width="10%">WARN</th><th class="crit" width="10%">CRIT</th><th class="unknown" width="10%">UNKNOWN</th></tr></thead>
<tbody>
EOF
}
function htmlHostAlerts
{
# End HTML Table for HOST HEALTH SUMMARY and start HTML Table for HOST ALERTS
cat <<EOF >> $HTMLFILE
</tbody>
</table></div>
<br/><br/>
<div class="datagrid2"><table>
<thead><tr><th class="header2" colspan="3">HOST ALERTS</th></thead>
<thead><tr><th class="host2">HOST</th><th class="host2">ALERT</th><th class="host2">DESCRIPTION</th></tr></thead>
<tbody>
EOF
}
function htmlFooter
{
# End HTML for Email Body
cat <<EOF >> $HTMLFILE
</tbody>
</table></div>
<br /><br />
<p align="justify">ecMK is an application that allows users to request the health status (from Check_MK) of IT Infrastructure via email. Refer <b><a href="http://wiki.corp.abc.com/index.php/ecMK#ecMK_Usage">ecMK</a></b> for more details.</p>
</body>
</html>
EOF
}
function htmlInvalidApp
{
# Start HTML for Email Body when a request for health status for invalid application(s)/host(s) is received
cat <<EOF >> $HTMLFILE
<div class="invalid">
You have sent an <b>INVALID</b> request for Application/Host Health status. In order to request Application health status, use <b>App=&lt;app name&gt;</b> in the email body. E.g. App=cards. In order to request Host health status, use <b>Host=&lt;host name&gt;</b> in the email body. E.g. Host=vtorcrddv01. <br />
Given below is a list of valid applications: <br /><br />
</div>
<div class="invalid"><table>
<thead><tr><th class="header1">APPLICATIONS</th></tr></thead>
<tbody>
EOF
}
#
# Post-Processing Functions
#
function doHousekeep
{
# Housekeeping - cleanup
if [ -f $MAILFILE ]; then
   rm $MAILFILE
fi
find $DATADIR -type f -name "*.tsv" -mtime +90 | xargs rm -f
}
function collectStats
{
# Collect statistics on script usage
if [ -f $DATAFILE ]; then
   echo "${TIMESTAMP}~${sender}~${myapps}~${myhosts}" >> $DATAFILE
else
   echo "TIMESTAMP~SENDER~APPS~HOSTS" > $DATAFILE
   echo "${TIMESTAMP}~${sender}~${myapps}~${myhosts}" >> $DATAFILE
fi
}
#####################################################################################
# Main
#####################################################################################
# Accept email from postfix
cat - > $MAILFILE
# Parse email
parseMail
# Check for NDR
if [ `ignoreNDR` -eq 1 ]; then
   collectStats
   echo "${TIMESTAMP} : Received NDR, ignoring." >> $LOGFILE
   doHousekeep
   exit 0
fi
# Start building HTML for EMail Body
htmlInit
# Validate app(s) and host(s)
unset capp chost
for a in `echo $myapps | sed 's/,/ /g'`
        do
                capp="`validateApp ${a}` ${capp}"
        done
if [ -n "${capp}" ]; then
        for h in $capp
                do
                        ah="`lqlAH $h | cut -d';' -f2 | sed 's/,/ /g'` ${ah}"
                done
fi
if [ -n "${ah}" -o -n "`echo $myhosts | sed 's/,/ /g'`" ]; then
        for ch in $ah `echo $myhosts | sed 's/,/ /g'`
                do
                        chost="`validateHost ${ch}` ${chost}"
                done
fi
# Work on app(s) and host(s)
if [ -n "${chost}" ]; then
        htmlHostStatus
        r=1
        s1t=s2t=s3t=0
        for myhost in $chost
                do
                        svcs=`lqlHS $myhost`
                        s0=`echo $svcs | cut -d';' -f1`
                        s1=`echo $svcs | cut -d';' -f2`
                        s2=`echo $svcs | cut -d';' -f3`
                        s3=`echo $svcs | cut -d';' -f4`
                        if [ $((r%2)) -eq 1 ]; then
                                cat<<EOF >> $HTMLFILE
                                <tr><td><a href="https://mysitecmk/mysite/check_mk/view.py?view_name=host&host=${myhost}">${myhost}</a></td><td>${s0}</td><td>${s1}</td><td>${s2}</td><td>${s3}</td></tr>
EOF
                        else
                                cat<<EOF >> $HTMLFILE
                                <tr class="alt"><td><a href="https://mysitecmk/mysite/check_mk/view.py?view_name=host&host=${myhost}">${myhost}</a></td><td>${s0}</td><td>${s1}</td><td>${s2}</td><td>${s3}</td></tr>
EOF
                        fi
                        r=$((r+1))
                        s1t=$((s1t+s1))
                        s2t=$((s2t+s2))
                        s3t=$((s3t+s3))
                done
                if [ $s1t -gt 0 -o $s2t -gt 0 -o $s3t -gt 0 ]; then
                        htmlHostAlerts
                        for myhost in $chost
                                do
                                        svcs=`lqlHS $myhost`
                                        s0=`echo $svcs | cut -d';' -f1`
                                        s1=`echo $svcs | cut -d';' -f2`
                                        s2=`echo $svcs | cut -d';' -f3`
                                        s3=`echo $svcs | cut -d';' -f4`
                                        /omd/sites/mysite/local/bin/check_mk -nv $myhost > $CMKFILE
                                        if [ $s1 -gt 0 ]; then
                                                grep "WARN -" $CMKFILE | while read line
                                                do
                                                        s1_svc=`echo $line | cut -d'-' -f2-`
                                                        cat<<EOF >> $HTMLFILE
                                                        <tr><td>${myhost}</td><td class="warn">WARN</td><td>${s1_svc}</td></tr>
EOF
                                                done
                                        fi
                                        if [ $s2 -gt 0 ]; then
                                                grep "CRIT -" $CMKFILE | while read line
                                                do
                                                        s2_svc=`echo $line | cut -d'-' -f2-`
                                                        cat<<EOF >> $HTMLFILE
                                                        <tr><td>${myhost}</td><td class="crit">CRIT</td><td>${s2_svc}</td></tr>
EOF
                                                done
                                        fi
                                        if [ $s3 -gt 0 ]; then
                                                grep "UNKNOWN -" $CMKFILE | while read line
                                                do
                                                        s3_svc=`echo $line | cut -d'-' -f2-`
                                                        cat<<EOF >> $HTMLFILE
                                                        <tr><td>${myhost}</td><td class="unknown">UNKNOWN</td><td>${s3_svc}</td></tr>
EOF
                                                done
                                        fi
                                done
                htmlFooter
                elif [ $s1t -eq 0 -a $s2t -eq 0 -a $s3t -eq 0 ]; then
                        echo "</tbody></table></div><br/><br/><h3>OVERALL HEALTH : <font style=\"font-family: Verdana, Arial, Helvetica, sans-serif; color:green;\">OK</font></h3><p align=\"justify\">ecMK is an application that allows users to request the health status (from Check_MK) of IT Infrastructure via email. Refer <b><a href=\"http://wiki.corp.abc.com/index.php/ecMK#ecMK_Usage\">ecMK</a></b> for more details.</p></body></html>" >> $HTMLFILE
                fi
                if [ -n "${capp}" ]; then
                        sub="Application Health Status : ${capp}"
                else
                        sub="Host Health Status : ${chost}"
                fi
                mutt -F ${MUTTRC} -s "${sub}" $sender < $HTMLFILE
else
        htmlInvalidApp
        v_apps=`lqlHG`
        for v in $v_apps
                do
                        cat<<EOF >> $HTMLFILE
                        <tr><td class="alt">${v}</td></tr>
EOF
                done
        htmlFooter
        mutt -F ${MUTTRC} -s "Health Status : INVALID Request" $sender < $HTMLFILE
fi
collectStats
doHousekeep