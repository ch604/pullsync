package_accounts() { #runs packagefuncion() in parallel and starts the syncprogress() command to display the syncing info
	ec yellow "Packaging cpanel accounts externally and restoring on local server..."
	# blank the hostsfile temp files
	> $hostsfile
	> $hostsfile_alt
	# make the folder for cpmove files
	mkdir -p $dir/cpmovefiles
	# set old main ip for checking restoration to dedicated ip
	old_main_ip=`grep "ADDR\ [0-9]" $dir/etc/wwwacct.conf | awk '{print $2}' | tr -d '\n'`
	[ "old_main_ip" = "" ] && old_main_ip=`cat $dir/var/cpanel/mainip`
	# set user total for progress display
	user_total=`echo $userlist |wc -w`
	# if useing dbbackup schema, prepare target for db restores
	[ $dbbackup_schema ] && prep_for_mysql_dbsync
	echo "$refreshdelay" > $dir/refreshdelay
	if [ "$(echo $realresellers)" ]; then #use echo to avoid false positive on whitespace
		# run resellers first if there are any
		ec yellow "Running $(cat $dir/realresellers.txt | wc -w) resellers first..."
		parallel --jobs $jobnum -u 'packagefunction {#} {} >$dir/log/looplog.{}.log' ::: $realresellers &
		syncprogress $!
		remainingusers=`cat $dir/nonresellers.txt`
		remainingcount=$(( $user_total - $(cat $dir/realresellers.txt | wc -w) ))
		if [ ! $remainingcount -eq 0 ]; then
			ec yellow "Running remaining $remainingcount users..."
			parallel --jobs $jobnum -u 'packagefunction {#} {} >$dir/log/looplog.{}.log' ::: $remainingusers &
			syncprogress $!
		fi
	else
		# if there are no resellers, run userlist as saved
		parallel --jobs $jobnum -u 'packagefunction {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
		syncprogress $!
	fi
}
