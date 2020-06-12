restorecontact() { #change the whm email address back to what was saved in pausecontact()
	[ ! -f $dir/whmcontact.txt ] && return # bail if there is nothing to restore
	ec yellow "Restoring WHM email address..."
	# set the root forwarder address
	if [ "$setcontact" ] && [ -f $dir/root/.forward ]; then
		/usr/local/cpanel/bin/whmapi1 set_user_email_forward_destination user=root forward_to=$(cat ${dir}/root/.forward) 2>&1 | stderrlogit 3
	elif [ ! "$setcontact" ] && [ -f /root/.forward.syncbak ]; then
		/usr/local/cpanel/bin/whmapi1 set_user_email_forward_destination user=root forward_to=$(cat /root/.forward.syncbak) 2>&1 | stderrlogit 3
	elif [ ! "$setcontact" ]; then
		/usr/local/cpanel/bin/whmapi1 set_user_email_forward_destination user=root forward_to=$(cat ${dir}/.forward) 2>&1 | stderrlogit 3
	fi
	# delete and replace the contactemail line
	sed -i '/^CONTACT[PAGER|EMAIL].*/d' /etc/wwwacct.conf
	echo -e "CONTACTPAGER `cat $dir/whmcontact.txt`\nCONTACTEMAIL `cat $dir/whmcontact.txt`" >> /etc/wwwacct.conf
}
