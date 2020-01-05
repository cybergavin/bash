#!/bin/bash
# Created By     :  mrkips (Cybergavin)
# Created On     :  31st March 2012
# Description    :  This script queries the mediawiki database and sends a notification regarding page creation. Reminds users about the existence of the wiki and what's in there.
#####################################################################################
#
# Variables
#
EMAIL_RECIPIENTS="wikiusers@abc.com"
REPORT_DATE=$(date '+%Y%m%d' --date="yesterday")
REPORT_DATE_FORMAIL=$(date '+%d-%b-%Y' --date="yesterday")
WIKI_BASEURL="http://wiki.abc.com/wiki/index.php/"
#
# Functions
#
getDBdata()
{
mysql -u wiki -p'xxxxx' --skip-column-names wiki <<EOSQL
connect wiki;
select rc_title, rc_user_text from recentchanges
where rc_timestamp like '$REPORT_DATE%'
and rc_type = 1
and rc_namespace=0;
quit
EOSQL
}
#
# Main
#
mail -s "ABC Wiki : New Page Notification For $REPORT_DATE_FORMAIL" $EMAIL_RECIPIENTS <<EOMAIL
Hi
 
 Given below are Pages created on the ABC Wiki ( http://wiki.abc.com ) yesterday ($REPORT_DATE_FORMAIL) along with their authors:
  
  `getDBdata | awk -v a="$WIKI_BASEURL" '{printf "%-70s %s %s\n", a$1,"-", $2}'`
   
EOMAIL
#
##################################### T H E     E N D ###############################
