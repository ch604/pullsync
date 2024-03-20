synctype_logic() { #case statement for performing server to server sync tasks. gets specific variables and establishes ssh connection via oldmigrationcheck() before starting.
	echo "synctype: $synctype" | logit
	echo "Ping @\$user in slack upon successful completion? [blank for none, will instead ping @migration-team]: " | logit && rd lwuser

	oldmigrationcheck # see if any old migrations exist and option to use these for connection info
	if [ "$oldip" ]; then
		ip=$oldip
		[ "$oldport" ] && port=$oldport
		getport
	else
		#if no choice was made, get new connection info
		getip
		getport
	fi

	# generate the ssh key and make the initial connection to the source server
	sshkeygen

	# we need /etc/userdomains for the domainlist conversion, might as well get things now.
	ec yellow "Transferring some config files over from old server to $dir"
	rsync -RL $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:"`echo $filelist`" $dir/ --exclude=named.run --exclude=named.log --exclude=named.log-*.gz --exclude=chroot --delete 2>&1 | stderrlogit 4
	[ ! -d $dir/var/cpanel/users ] && rsync -RL $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip$(for i in $filelist; do echo -n ":$i "; done) $dir/ --exclude=named.run --exclude=named.log --exclude=named.log-*.gz --exclude=chroot --delete 2>&1 | stderrlogit 4

	# determine if the target server is lw openstack so we can control some options. send one ping (one ping only) to make sure we can reach the openstack controller before trying to curl.
	[ ! "$(which jq 2> /dev/null)" ] && yum -y -q install jq
	[ "$(which jq 2> /dev/null)" ] && [ $(ping 169.254.169.254 -c1 -W2 &> /dev/null; echo $?) -eq 0 ] && [ "$(curl -s http://169.254.169.254/openstack/2018-08-27/meta_data.json | jq '.[]' 2> /dev/null | awk -F\" '/mh_fileserver/ {print $4}')" = "host" ] && touch $dir/iamopenstack

	case $synctype in
		single|list|domainlist|all)
			getuserlist
			getversions
			lower_ttls
			unowneddbs
			initialsync_main
			;;
		skeletons)
			getuserlist
			getversions
			lower_ttls
			initialsync_main
			;;
		update)
			getuserlist
			securityfeatures
			cpnat_check
			dnscheck
			dnsclustering
			updatesync_main
			;;
		prefinal)
			getuserlist
			cpnat_check
			dnscheck
			dnsclustering
			printrdns
			space_check
			securityfeatures
			unowneddbs
			mysql_listgen
			ec green "Hope you make good decisions for your final sync!"
			;;
		final)
			rsyncspeed=0 #change bwlimit to 0 to unlimit rsync speed
			getuserlist
			ipswapcheck
			securityfeatures
			dnsclustering
			cpnat_check
			#skip dnscheck if theres already a nameserver_summary.txt copied from olddir, or if ipswap set
			[ ! "$ipswap" -a ! "$stormipswap" -a ! "$dummyipswap" ] && [ ! -f $dir/nameserver_summary.txt ] && dnscheck
			printrdns
			finalsync_main
			;;
		homedir)
			getuserlist
			if yesNo 'Use --update flag for rsync? If files were updated on the destination server they wont be overwritten'; then
				rsync_update="--update"
			fi
			if yesNo 'Add "cache" to the rsync --exclude line? This will exclude all cache folders from the sync. Only add this if explicitly requested or required for long running syncs! You should say NO if you are not sure.'; then
				rsync_excludes=`echo --exclude=cache $rsync_excludes`
			fi
			misc_ticket_note
			lastpullsyncmotd
			user_total=`echo $userlist |wc -w`
			parallel --jobs $jobnum -u 'rsync_homedir_wrapper {#} {} | tee -a $dir/log/looplog.{}.log' ::: $userlist
			;;
		email*)
			getuserlist
			if yesNo "Use --update for rsync?"; then
				rsync_update="--update"
			fi
			misc_ticket_note
			lastpullsyncmotd
			user_total=`echo $userlist |wc -w`
			parallel --jobs $jobnum -u 'rsync_email {#} {}' ::: $userlist
			;;
		mysql)
			getuserlist
			unowneddbs
			mysql_listgen
			if yesNo "Do you want to use dbscan during the transfer?"; then unset nodbscan; else nodbscan=1; fi
			if yesNo "Do you want to backup sql files before import? (recommended)"; then unset skipsqlzip; else skipsqlzip=1; fi
			misc_ticket_note
			lastpullsyncmotd
			parallel_mysql_dbsync
			[ -f $dir/dbdump_fails.txt ] && ec red "Some databases failed to dump properly, please recheck:" && cat $dir/dbdump_fails.txt
			[ -f $dir/matchingchecksums.txt ] && ec green "Some tables had matching checksums and were skipped:" && cat $dir/matchingchecksums.txt
			[ -f $dir/dbmalware.txt ] && ec red "Some databases may have malware, which usually indicates that the CMS is totally hosed. Please check manually:" && cat $dir/dbmalware.txt
			for user in $userlist; do
				eternallog $user
			done
			;;
		pgsql)
			getuserlist
			misc_ticket_note
			lastpullsyncmotd
			pgsql_dbsync
			for user in $userlist; do
				eternallog $user
			done
			;;
		versionmatching)
			getversions
			do_installs=1
			matching_menu
			phpmenu
			do_optimize=1
			optimize_menu
			misc_ticket_note
			cpconfbackup
			installs
			optimizations
			restorecontact
			mysqlcalc
			[ -f $dir/uninstallable.txt ] && ec red "Some items could not be installed! Please install these manually!" && cat $dir/uninstallable.txt
			;;
	esac

	finish_up
}
