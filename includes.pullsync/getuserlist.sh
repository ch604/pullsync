getuserlist() { # get user list for different sync types
	local userlist_count userlist_some
	# a list of users
	if echo -e "list\nemaillist\nskeletons" | grep -qx $synctype; then
		[ ! -f "$userlistfile" ] && { ec lightRed "Did not find $userlistfile!"; exitcleanup 4 ;}
		userlist=$(cat "$userlistfile")
	# a list of domains
	elif  [ "$synctype" == "domainlist" ] ; then
		[ ! -f "$domainlistfile" ] && { ec lightRed "Did not find $domainlistfile!"; exitcleanup 5 ; }
		#lowercase the domainlist
		sed -i -e 's/\(.*\)/\L\1/' "$domainlistfile"
		cp -rp "$domainlistfile" "$dir/"
		#get users from a domainlist, $dir/etc/userdomains needs to exist already
		userlist=$(while read -r domain; do
			awk -F" " '/^'"$domain"':/ {print $2}' "$dir/etc/userdomains"
		done < "$domainlistfile")
	#all users
	elif echo -e "all\nemail" | grep -qx $synctype; then
		userlist=$(sssh "find /var/cpanel/users/ -maxdepth 1 -type f -printf \"%f\n\"")
	# single user
	elif [ "$synctype" == "single" ] ; then
		ec white "What is the user you would like to migrate?"
		rd userlist
		ips_free=$(/usr/local/cpanel/bin/whmapi1 listips | grep -c "used: 0")
		ec yellow "There are $ips_free available dedicated IPs on this server."
		if yesNo "Restore to dedicated ip?"; then
			single_dedip="1"
		fi
	else #final and other syncs
		# check for users from the last pullsync
		if [ -f "$olddir/userlist.txt" ] && [ "$oldusercount" -gt 0 ] && [ ! "$autopilot" ]; then
			ec lightGreen "Previous sync from ip $oldip at $oldstarttime found in $olddir/userlist.txt."
			ec yellow "Count of old users: $oldusercount"
			ec yellow "First 10 old users: $someoldusers"
			if yesNo "Are these users correct?"; then
				userlist=$(cat "$olddir/userlist.txt")
			fi
		fi
		# check for /root/userlist.txt
		userlist_count=0
		[ -f "$userlistfile" ] && userlist_count=$(cat "$userlistfile" | wc -w)
		if [ "$userlist_count" -gt 0 ] && [ ! "$userlist" ]; then
			ec lightGreen "Userlist found in $userlistfile."
			ec yellow "Counted $userlist_count users."
			userlist_some=$(paste -sd' ' "$userlistfile" | cut -d' ' -f1-10)
			ec yellow "First 10 users found: $userlist_some"
			if [ ! "$autopilot" ]; then
				if yesNo "Are these users correct?"; then
					userlist=$(cat "$userlistfile")
				fi
			else
				userlist=$(cat "$userlistfile")
			fi
		fi
		if [ ! "$userlist" ]; then
			# no previous sync found, ask for all users
			if [ ! "$autopilot" ]; then
				if yesNo "No userlist found, sync all remote users?"; then
					userlist=$(sssh "find /var/cpanel/users/ -maxdepth 1 -type f -printf \"%f\n\"")
				else
					ec lightRed "Error: No userlist was defined, quitting."
					exitcleanup 4
				fi
			else
				userlist=$(sssh "find /var/cpanel/users/ -maxdepth 1 -type f -printf \"%f\n\"")
			fi
		fi
	fi
	#if we still dont have a userlist, quit
	[ "$(echo $userlist | wc -w)" = "0" ] && ec red "Userlist is blank! What are you trying to do here? Really?" && exitcleanup 4
	if [ "$synctype" == "domainlist" ]; then
		#warn if there are extra domains attached to the users being synced for domainlist syncs
		extrasd=$(for each in $userlist; do awk -F: '/:\ '$each'$/ {print $1}' $dir/etc/userdomains; done)
		for each in $(cat $domainlistfile); do
			extrasd=$(echo $extrasd | tr ' ' '\n' | grep -vx $each)
		done
		if [ "$extrasd" ]; then
			ec yellow "The following domains will also be synced for your domainlist sync:"
			echo $extrasd | logit
			say_ok
		fi
	fi

	sanitize_userlist

	#generate domainlist to go with userlist
	domainlist=$(for user in $userlist; do awk -F= '/^DNS.*=/ {print $2}' $dir/var/cpanel/users/$user; done)
	echo $domainlist > $dir/domainlist.txt

	#reorder the userlist so resellers are first
	[ ! "$synctype" == "single" ] && resellercheck

	#store the userlist all over
	echo $userlist | sssh "cat - >> $remote_tempdir/syncinfo.txt"

	#check for conflicts
	accountconflicts
	noncpanelitems
	ec yellow "Counted $(echo $userlist | wc -w) users in list."
}
