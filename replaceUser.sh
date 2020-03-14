#!/bin/bash
# Created By	:	cybergavin
# Created On	:	12-MAR-2020
# Description	:	QAD script to change a user login name. 
# USER-DEFINED  :   Replace 'user1' and 'user2' by the actual users to be swapped. user2 (new_user) must not be created before executing this script.
#                   Will not execute if the old_user is logged in or owns a running process.
#####################################################################################################################################################
old_user=user1
new_user=user2
# Modify user's login name
sudo usermod -l $new_user $old_user
# Modify user's group name if same as user name
[[ -n "`grep \"^${old_user}\" /etc/group`" ]] && sudo groupmod -n $new_user $old_user
# Rename any file or directory named with the old user's login name
for i in $(sudo find / -name "$old_user" -user $new_user 2>/dev/null)
do
        sudo mv $i `dirname $i`/${new_user}
done
# Change home directory for new user as "usermod" does not do it
ohdir=`grep "^${new_user}" /etc/passwd |cut -d: -f6`
if [ -n "`echo $ohdir | grep \"${old_user}\"`" ]; then
        nhdir=`echo $ohdir | sed "s/${old_user}/${new_user}/g"`
        sudo usermod -d $nhdir ${new_user}
fi
# Replace old user by new user in the sudoers file
sudo sed -i "s/${old_user}/${new_user}/g" /etc/sudoers