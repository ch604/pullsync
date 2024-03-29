getuserlist() { # get user list for different sync types
	# a list of users
	if [[ "$synctype" == "list" || "$synctype" == "emaillist" || "$synctype" == "skeletons" ]]; then
		[ ! -f "$userlistfile" ] && { ec lightRed "Did not find $userlistfile!"; exitcleanup 4 ;}
		userlist=$(cat $userlistfile | sort -u | egrep -vx "${badusers}")
	# a list of domains
	elif  [ "$synctype" == "domainlist" ] ; then
		[ ! -f "$domainlistfile" ] && { ec lightRed "Did not find $domainlistfile!"; exitcleanup 5 ; }
		#lowercase the domainlist
		sed -i -e 's/\(.*\)/\L\1/'  $domainlistfile
		cp -rp $domainlistfile $dir/
		#get users from a domainlist, $dir/etc/userdomains needs to exist already
		userlist=$(for domain in $(cat $domainlistfile); do
			awk -F" " '/^'$domain':/ {print $2}' $dir/etc/userdomains
		done | sort -u | egrep -vx "${badusers}")
	#all users
	elif [[ "$synctype" == "all" || "$synctype" == "email" ]] ; then
		userlist=$(sssh "\ls -A /var/cpanel/users/" | sort -u | egrep -v "^HASH" | egrep -vx "${badusers}")
	# single user
	elif [ "$synctype" == "single" ] ; then
		ec white "What is the user you would like to migrate?"
		rd userlist
		ips_free=$(/usr/local/cpanel/bin/whmapi1 listips | grep used\:\ 0 | wc -l)
		ec yellow "There are $ips_free available dedicated IPs on this server."
		if yesNo "Restore to dedicated ip?"; then
			single_dedip="yes"
		else
			single_dedip="no"
		fi
	else #final and other syncs
		# check for users from the last pullsync
		if [ -f $olddir/userlist.txt ] && [ $oldusercount -gt 0 ] && [ ! "$autopilot" ]; then
			ec lightGreen "Previous sync from ip $oldip at $oldstarttime found in $olddir/userlist.txt."
			ec yellow "Count of old users: $oldusercount"
			ec yellow "First 10 old users: $someoldusers"
			if yesNo "Are these users correct?"; then
				userlist=$(cat $olddir/userlist.txt | sort -u | egrep -vx "${badusers}")
			fi
		fi
		# check for /root/userlist.txt
		if [ -f /root/userlist.txt ] ;then
			userlist_count=$(cat /root/userlist.txt | wc -w)
		else
			userlist_count=0
		fi
		if [ $userlist_count -gt 0 ] && [ ! "$userlist" ]; then
			ec lightGreen "Userlist found in /root/userlist.txt."
			ec yellow "Counted $userlist_count users."
			userlist_some=$(cat /root/userlist.txt | tr '\n' ' '| cut -d' ' -f1-10)
			ec yellow "First 10 users found: $userlist_some"
			if [ ! "$autopilot" ]; then
				if yesNo "Are these users correct?"; then
					userlist=$(cat /root/userlist.txt | sort -u | egrep -vx "${badusers}")
				fi
			else
				userlist=$(cat /root/userlist.txt | sort -u | egrep -vx "${badusers}")
			fi
		fi
		if [ ! "$userlist" ]; then
			# no previous sync found, ask for all users
			if [ ! "$autopilot" ]; then
				if yesNo "No userlist found, sync all remote users?"; then
					userlist=$(sssh "\ls -A /var/cpanel/users/" | sort -u | egrep -v "^HASH" | egrep -vx "${badusers}")
				else
					ec lightRed "Error: No userlist was defined, quitting."
					exitcleanup 4
				fi
			else
				userlist=$(sssh "\ls -A /var/cpanel/users/" | sort -u | egrep -v "^HASH" | egrep -vx "${badusers}")
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
		if [ ! "$extrasd" = "" ]; then
			ec yellow "The following domains will also be synced for your domainlist sync:"
			echo $extrasd | logit
			say_ok
		fi
	fi

	#generate domainlist to go with userlist
	domainlist=$(for user in $userlist; do awk -F= '/^DNS.*=/ {print $2}' $dir/var/cpanel/users/$user; done)
	echo $domainlist > $dir/domainlist.txt

	#reorder the userlist so resellers are first
	[ ! "$synctype" == "single" ] && resellercheck

	#store the userlist all over
	echo $userlist > "$dir/userlist.txt"
	echo $userlist > /root/userlist.txt
	echo $userlist | sssh "cat - >> $remote_tempdir/syncinfo.txt"

	#check for conflicts
	accountconflicts
	noncpanelitems
	ec yellow "Counted $(echo $userlist | wc -w) users in list."
}
