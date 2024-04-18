synctype_logic() { #case statement for performing server to server sync tasks. gets specific variables and establishes ssh connection via oldmigrationcheck() before starting.
	echo "synctype: $synctype" | logit

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
	rsync -RL $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip$(for i in $filelist; do echo -n ":$i "; done) $dir/ --exclude=named.run --exclude=named.log --exclude=named.log-*.gz --exclude=chroot --delete 2>&1 | stderrlogit 4

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
			multihomedir_check
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
			[ ! "$ipswap" ] && [ ! -f $dir/nameserver_summary.txt ] && dnscheck
			printrdns
			finalsync_main
			;;
		homedir)
			getuserlist
			homedirsync_main
			;;
		email*)
			getuserlist
			emailsync_main
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
			[ -f $dir/dbdump_fails.txt ] && ec red "Some databases failed to dump properly, please recheck (cat $dir/dbdump_fails.txt):" && cat $dir/dbdump_fails.txt | logit
			[ -f $dir/matchingchecksums.txt ] && ec green "Some tables had matching checksums and were skipped (cat $dir/matchingchecksums.txt):" && cat $dir/matchingchecksums.txt | logit
			[ -f $dir/dbmalware.txt ] && ec red "Some databases may have malware, which usually indicates that the CMS is totally hosed. Please check manually (cat $dir/dbmalware.txt):" && cat $dir/dbmalware.txt | logit
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
			[ -f $dir/uninstallable.txt ] && ec red "Some items could not be installed! Please install these manually! (cat $dir/uninstallable.txt):" && cat $dir/uninstallable.txt | logit
			;;
	esac

	finish_up
}
