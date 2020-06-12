syncprogress() { #prints the sync status every few seconds over the same window, to show what is being synced at any given time. tails the individual log files for each package_account() to get the sync position, uses ps to determine which package functions are still running. prints the file open by the rsync process if log says it is mid rsync. $1 is pid of the parallel process, exits when parallel is done.
	# experience infinity
	clear
	local c=$(tput el) #clear to end of line
	while kill -0 $1 2> /dev/null; do
		#read refresh delay file every loop, ensure sanity
		refreshdelay=$(cat $dir/refreshdelay); [[ ! $refreshdelay =~ ^[0-9]+$ || $refreshdelay -gt 60 ]] && refreshdelay=3
		# get a list of running parallel processes (packagefunction), getting the unique list of process numbers and usernames
		local runningprocs=`ps faux | grep packagefunction | egrep -v '(parallel|grep)' | awk '{print $(NF-2), $(NF-1)}' | sort -u`
		# put that variable into processprogress()
		processprogress
		if [ -s $hostsfile ] ; then
			# if anything was written to the hosts file, list the last few lines so spot testing can be done
			ecnl white "Last 3 hosts file lines:$c"
			ecnl yellow "`tail -3 $hostsfile | head -1`$c"
			ecnl yellow "`tail -2 $hostsfile | head -1`$c"
			ecnl yellow "`tail -1 $hostsfile`$c"
			echo -e "$c"
		else
			# otherwise skip a few lines
			echo -e "$c\n$c\n$c\n$c\n$c"
		fi
		if [ -f $dir/did_not_restore.txt ]; then
			# display mid-sync if there are restore errors
			ecnl lightRed "Some users did not restore:$c"
			ecnl lightRed "`cat $dir/did_not_restore.txt | tr '\n' ' '`$c"
			echo -e "$c"
		else
			# otherwise skip a few lines
			echo -e "$c\n$c\n$c"
		fi
		# invert count to clear off extra data when you go from 3 to 2 restores, for instance
		for each in `seq $numprocs 2`; do
			echo -e "$c\n$c\n$c"
		done
		# clear to the bottom
		for each in `seq 30 $(tput lines)`; do
			echo -e "$c"
		done
		# check for stuck transfers
		if [ ! -z $recheckpid ]; then
			# there was a potentially stuck session found from the 'else' statement. check for it now
			if [ "$recheckpid" = "`ps fax | grep view_transfer | grep -v grep | awk '{print $1}'`" ]; then
				# if the active view_transfer matches the one from the last check, increment count
				(( recheck += 1 ))
				if [ "$recheck" = "9" ]; then
					# restore has been stuck for 30 seconds with finished child, kill the parent
					ec red "Killing stuck transfer_session ${active_restorepkg}..."
					echo "killed $active_restorepkg pid $recheckpid: `ps fax | grep view_transfer | grep -v grep`" >> errorlogit 2
					kill $recheckpid 2>&1 | stderrlogit 2
					unset recheckpid recheck active_restorepkg # unset variables to escape this loop next time
				fi
			else
				unset recheckpid recheck active_restorepkg #we have a new view_transfer pid
			fi
		else
			echo -e "$c" # clear text from last kill if any
			# get the session id of the restorepkg in progress
			active_restorepkg=`ps fax | grep view_transfer | grep -v grep | awk '{print $NF}' | head -1`
			if [ ! -z $active_restorepkg ] && [ -f /var/cpanel/transfer_sessions/$active_restorepkg/item-RESTORE* ]; then
				# active restore session with child process done, might be stuck. get the pid number to recheck.
				recheckpid=`ps fax | grep view_transfer | grep -v grep | awk '{print $1}' | head -1`
				[ -z $recheckpid ] && unset recheckpid recheck active_restorepkg # view_transfer ended cleanly before we could get to it
			else
				unset recheckpid recheck active_restorepkg # no active restore session
			fi
		fi
		# wait for more stuff to happen
		sleep $refreshdelay
	done
	clear
}
