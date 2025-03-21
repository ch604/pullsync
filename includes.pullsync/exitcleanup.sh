exitcleanup() { #accepts exit code to use as $1. removes temporary data, cleans up ssh sessions, unsets exported variables, and runs the slackhook() to ping completion.
	local dirsize
	#remove pullsync key from remote authorized keys on remote server
	if [ -f $dir/ip.txt ] && [ -f $dir/keyname.txt ]; then
		ec yellow "Removing remote pullsync ssh keys..."
		local ip sshargs
		ip=$(cat $dir/ip.txt)
		sshargs="$sshargs -p$(cat $dir/port.txt) -i $(cat $dir/keyname.txt)"
		[ ! "$ipswap" ] && sssh "sed -i /pullsync/d ~/.ssh/authorized_keys ; [ \$(which firewall 2>/dev/null) ] && firewall start"
		# needs to be after ssh commands!
		if which csf &> /dev/null; then
			csf -ar $ip 2>&1 | stderrlogit 4
		elif which apf &> /dev/null; then
			sed -i.pullsyncbak '/'$ip'/d' /etc/apf/allow_hosts.rules
			apf -r &> /dev/null &
		fi
	fi
	if [ ! "$autopilot" ]; then
		ec yellow "Killing remnant SSH processes..."
		for connection in $(ps x | awk '/ssh/ && /pullsync/ && !/ awk / {print $1}'); do
			echo "$connection" | logit
			kill "$connection"
		done
	fi
	ec yellow "Removing local pullsync ssh keys..."
	[ -f /root/.ssh/config ] && sed -i '/\#added\ by\ pullsync/,+4d' /root/.ssh/config
	\rm -f /root/.ssh/pullsync*
	#restore whm contact during control_c if needed
	[ "$1" ] && [ "$1" = "130" ] && restorecontact
	#determine if noop or failed connection, change foldername and remake symlink
	if [ ! -f $dir/ip.txt ]; then
		ec yellow "No-op detected, renaming folder..."
		mv "$dir.$starttime" "$noopdir.$starttime"
		rm -f "$dir"
		ln -s "$noopdir.$starttime" "$dir"
	fi
	#add cleanup cron
	ec yellow "Adding cleanup cron..."
	cat > /etc/cron.d/pullsync-cleanup << EOF
30 0 * * * root /bin/bash -c 'if [ ! "\$(find /home/temp/ -maxdepth 1 -type d -mtime -14 \( -name "pullsync*" -o -name "noop-pullsync*" \))" -a ! -f /home/temp/pullsync/pullsync.pid ]; then \\rm -rf /root/includes.pullsync/; \\rm -f /root/migration_malware_scan; \\rm -f /root/pullsync.sh; \\rm -f /etc/cron.d/pullsync-cleanup; fi'
EOF
	#print disk usage of all temp data
	dirsize=$(du -shc /home/temp/pullsync.* /home/temp/noop-pullsync.* 2>/dev/null | tail -1 | awk '{print $1}')
	ec white "Total disk usage by pullsync folders is: $dirsize"
	ec yellow "Your unique pullsync folder is: $dir.$starttime"
	ec yellow "Clearing lock file..."
	[ "$dir" ] && [ -f "$pidfile" ] && \rm -f "$pidfile"
	[ "$1" ] && [ "$1" = "9" ] && exit "$1" # bail before printing if exiting because of autopilot
	echo
	ec white "Started $starttime"
	ec white "Ended $(date +%F.%T)"
	if [ ! "$1" ] && [ "$slackhook_url" ]; then #if no special exit code and slackhook set, ping slack
		ec yellow "Posting completion to slack channel..."
		if [ -f "$dir/error.log" ] && grep -q ERROR "$dir/error.log"; then
			slackhook ff3333
		else
			slackhook
		fi
	fi
	ec lightGreen "Done!"
	if [ -f "$dir/error.log" ] && grep -q ERROR "$dir/error.log"; then
		ec red "There were errors of note! Make sure to check these! (cat $dir/error.log)"
	elif [ -f "$dir/error.log" ]; then
		ec lightRed "There were warnings and info logged in the error log. Make sure to check these. (cat $dir/error.log)"
	fi
	echo -en "\a" # sound the terimal bell
	[ "$1" ] && echo "exit code: $1" | logit
	#unset exported functions/variables
	unset -f packagefunction rsync_homedir hosts_file ec ecnl rsync_homedir_wrapper rsync_email rsync_email_wrapper mysql_dbsync mysql_dbsync_user malware_scan logit ts sssh install_ssl resetea4versions sanitize_dblist nameserver_registrar eternallog stderrlogit nonhuman human wpt_speedtest awkmedian ab_test errorlogit user_mysql_listgen wpt_initcompare finalfunction processprogress dbscan apache_user_includes fpmconvert progress_bar parallel_lwhostscopy parallel_usercollide parallel_domcollide parallel_unsynceduser parallel_unsynceddom parallel_unrestored set_ipv6 cpbackup_finish parallel_cllve parallel_vhostsearch parallel_zonesearch srsync parallel_dnslookup parallel_nslookup parallel_besttime parallel_mysql_dbsync user_pgsql_listgen pgsql_dbsync user_email_listgen record_mapping mysqlprogress
	unset dir userlist user_total remainingcount sshargs ip remote_tempdir rsyncargs rsyncspeed old_main_ip ded_ip_check single_dedip synctype rsync_update rsync_excludes hostsfile hostsfile_alt nocolor black grey red lightRed green lightGreen brown yellow blue lightBlue purple lightPurple cyan lightCyan white greyBg dblist_restore fpmconvert comment_crons malwarescan defaultea4profile log fixperms starttime mysqldumpopts stderrlog dbbackup_schema initsyncwpt dopgsync skipsqlzip nodbscan start_disk expected_disk homemountpoints finaldiff jobnum ipv6 mailjobnum sqljobnum cm hg wn xx c
	exit "${1:-0}"
}
