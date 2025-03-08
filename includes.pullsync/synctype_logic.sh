synctype_logic() { #case statement for performing server to server sync tasks. gets specific variables and establishes ssh connection via oldmigrationcheck() before starting.
	echo "synctype: $synctype" | logit
	[ "$(rpm --eval %rhel)" -le 7 ] && ec red "This is a cent7 or lower target! Get yourself up to alma8+! I won't quit on you but evaluate if you want to continue."

	oldmigrationcheck # see if any old migrations exist and option to use these for connection info
	[ "$oldip" ] && ip=$oldip
	getip
	[ "$oldport" ] && port=$oldport
	getport

	# generate the ssh key and make the initial connection to the source server
	sshkeygen
	# make sure we can parallel out the wazoo
	if [ "$(sssh "sshd -T" | awk '/^maxsessions/ {print $2}')" -lt 24 ]; then
		sssh "sed -i '/^MaxSessions/ s/^/#/' /etc/ssh/sshd_config; echo \"MaxSessions 24\" >> /etc/ssh/sshd_config; systemctl reload sshd || service sshd restart" 2>&1 | stderrlogit 4
	fi

	# we need /etc/userdomains for the domainlist conversion, might as well get things now.
	ec yellow "Transferring some config files over from old server to $dir"
	# shellcheck disable=SC2046,SC2086
	srsync -RL $ip$(for i in $filelist; do echo -n ":$i "; done) $dir/ --exclude=named.run --exclude=named.log --exclude=named.log-*.gz --exclude=chroot --delete 2>&1 | stderrlogit 4

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
			[ ! "$ipswap" ] && [ ! -f "$dir/nameserver_summary.txt" ] && dnscheck
			printrdns
			finalsync_main
			;;
		homedir)
			getuserlist
			securityfeatures
			cpnat_check
			dnscheck
			dnsclustering
			homedirsync_main
			;;
		email*)
			getuserlist
			securityfeatures
			cpnat_check
			dnscheck
			dnsclustering
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
			echo "$refreshdelay" > "$dir/refreshdelay"
			# shellcheck disable=SC2086
			parallel -j 100% 'record_mapping {}' ::: $userlist
			prep_for_mysql_dbsync
			echo "$dblist_restore" > "$dir/dblist.txt"
			while read -r -u9 db; do
				mysql_dbsync "$db"
			done 9< "$dir/dblist.txt"
			[ -f "$dir/dbdump_fails.txt" ] && ec red "Some databases failed to dump properly, please recheck (cat $dir/dbdump_fails.txt):" && logit < "$dir/dbdump_fails.txt"
			[ -f "$dir/matchingchecksums.txt" ] && ec green "Some tables had matching checksums and were skipped (cat $dir/matchingchecksums.txt):" && logit < "$dir/matchingchecksums.txt"
			[ -f "$dir/dbmalware.txt" ] && ec red "Some databases may have malware, which usually indicates that the CMS is totally hosed. Please check manually (cat $dir/dbmalware.txt):" && logit < "$dir/dbmalware.txt"
			for user in $userlist; do
				eternallog "$user"
			done
			;;
		pgsql)
			if sssh "pgrep 'postgres|postmaster' &> /dev/null" && pgrep 'postgres|postmaster' &> /dev/null; then
				getuserlist
				if yesNo "Do you want to backup local pgsql dumps before import? (recommended)"; then unset skipsqlzip; else skipsqlzip=1; fi
				misc_ticket_note
				lastpullsyncmotd
				# shellcheck disable=SC2086
				parallel -j 100% 'record_mapping {}' ::: $userlist
				prep_for_pgsql_dbsync
				for user in $userlist; do
					pglist=$(user_pgsql_listgen "$user")
					if [ "$pglist" ]; then
						ec cyan "DBs for $user:"
						echo "$pglist" | logit
						for db in $pglist; do
							ec blue "Importing pgsql db $db..."
							pgsql_dbsync "$db" "$user"
						done
						eternallog "$user"
					fi
				done
			else
				ec red "Postgres is not running on one or more servers. Did you click the wrong menu item?"
			fi
			;;
		versionmatching)
			getversions
			do_installs=1
			matching_menu
			phpmenu
			do_optimize=1
			optimize_menu
			security_menu
			misc_ticket_note
			cpconfbackup
			installs
			optimizations
			install_security
			restorecontact
			mysqlcalc
			[ -f "$dir/uninstallable.txt" ] && ec red "Some items could not be installed! Please install these manually! (cat $dir/uninstallable.txt):" && logit < "$dir/uninstallable.txt"
			;;
	esac

	finish_up
}
