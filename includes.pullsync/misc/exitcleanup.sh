exitcleanup() { #accepts exit code to use as $1. removes temporary data, cleans up ssh sessions, unsets exported variables.
	#remove pullsync key from remote authorized keys on remote server
	if [ -f $dir/ip.txt ] && [ -f $dir/keyname.txt ]; then
		ec yellow "Removing remote pullsync ssh keys..."
		local ip=`cat $dir/ip.txt`
		local sshargs="$sshargs -p$(cat $dir/port.txt) -i $(cat $dir/keyname.txt)"
		[ ! "$ipswap" ] && sssh "sed -i /pullsync/d ~/.ssh/authorized_keys ; [ \`which firewall 2>/dev/null\` ] && firewall start"
		# needs to be after ssh commands!
		if [ `which csf 2> /dev/null` ]; then
			csf -ar $ip 2>&1 | stderrlogit 4
		elif [ `which apf 2> /dev/null` ]; then
			sed -i.pullsyncbak '/'$ip'/d' /etc/apf/allow_hosts.rules
			apf -r &> /dev/null &
		fi
	fi
	if [ ! "$autopilot" ]; then
		ec yellow "Killing remnant SSH processes..."
		for connection in `ps x | grep ssh | grep pullsync | grep -v grep | awk '{print $1}'`; do
			echo "$connection" | logit
			kill $connection
		done
	fi
	ec yellow "Removing local pullsync ssh keys..."
	[ -f /root/.ssh/config ] && sed -i '/\#added\ by\ pullsync/,+4d' /root/.ssh/config
	rm -f /root/.ssh/pullsync*
	#determine if noop or failed connection, change foldername and remake symlink
	[ ! -f $dir/ip.txt ] && ec yellow "No-op detected, renaming folder..." && mv "$dir.$starttime" "$noopdir.$starttime" && rm -f "$dir" && ln -s "$noopdir.$starttime" "$dir"
	#add cleanup cron
	ec yellow "Adding cleanup cron..."
	cat > /etc/cron.d/pullsync-cleanup << EOF
30 0 * * * root /bin/bash -c 'if [ ! "\$(find /home/temp/ -maxdepth 1 -type d -mtime -14 \( -name "pullsync*" -o -name "noop-pullsync*" \))" ]; then rm -rf /root/includes.pullsync/; rm -f /root/pullsync.sh; rm -f /etc/cron.d/pullsync-cleanup; fi'
EOF
	#print disk usage of all temp data
	local dirsize=$(du -shc /home/temp/pullsync.* /home/temp/noop-pullsync.* 2>/dev/null | tail -1 | awk '{print $1}')
	ec white "Total disk usage by pullsync folders is: $dirsize"
	ec yellow "Clearing lock file..."
	[ "$dir" ] && [ -f "$pidfile" ] && rm -f "$pidfile"
	[ "$1" = "9" ] && exit $1 # bail before printing if exiting because of autopilot
	echo
	ec white "Started $starttime"
	ec white "Ended `date +%F.%T`"
	ec lightGreen "Done!"
	if [ ! $1 ]; then #if no special exit code, ping slack
		ec yellow "Posting completion to slack channel..."
		[ $errorsofnote ] && slackhook ff3333 || slackhook
		[ $errorsofnote ] && ec red "There were errors of note! Make sure to check these! (cat $dir/errors_of_note.txt)"
	fi
	echo -en "\a" # sound the terimal bell
	[[ "$1" ]] && echo "exit code: $1" | logit
	#unset exported functions/variables
	unset -f packagefunction rsync_homedir hosts_file ec ecnl rsync_homedir_wrapper rsync_email mysql_dbsync mysql_dbsync_2 logit ts sssh install_ssl resetea4versions sanitize_dblist nameserver_registrar eternallog stderrlogit nonhuman errorlogit user_mysql_listgen finalfunction processprogress dbscan
	unset dir user_total remainingcount sshargs ip remote_tempdir rsyncargs old_main_ip ded_ip_check single_dedip synctype rsync_update rsync_excludes hostsfile hostsfile_alt nocolor black grey red lightRed green lightGreen brown yellow blue lightBlue purple lightPurple cyan lightCyan white greyBg dblist_restore fcgiconvert comment_crons defaultea4profile log solrver fixperms starttime mysqldumpopts errlog dbbackup_schema dopgsync
	exit $1
}
