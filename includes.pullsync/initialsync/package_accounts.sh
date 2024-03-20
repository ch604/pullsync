package_accounts() { #runs packagefuncion() in parallel and starts the syncprogress() command to display the syncing info
	ec yellow "Packaging cpanel accounts externally and restoring on local server..."

	# blank the hostsfile temp files
	> $hostsfile
	> $hostsfile_alt

	# make the folder for cpmove files
	mkdir -p $dir/cpmovefiles

	# set old main ip for checking restoration to dedicated ip
	old_main_ip=$(awk '/ADDR [0-9]/ {print $2}' $dir/etc/wwwacct.conf | tr -d '\n')
	[ "old_main_ip" = "" ] && old_main_ip=$(cat $dir/var/cpanel/mainip)

	# set variables for progress display
	user_total=$(echo $userlist | wc -w)
	start_disk=0
	homemountpoints=$(for each in $(echo $localhomedir); do findmnt -nT $each | awk '{print $1}'; done | sort -u)
	for each in $(echo $homemountpoints); do
		local z=$(df $each | tail -n1 | awk '{print $3}')
		start_disk=$(( $start_disk + $z ))
	done
	if [ "$iusedrepquota" ]; then #TODO this includes mysql disk usage from space_check()
		expected_disk=$(( $start_disk + $remote_used_space ))
	else #TODO this isnt completely accurate either as it includes all users and linux files
		expected_disk=$remote_used_space
	fi

	# if using dbbackup schema, prepare target for db restores
	[ $dbbackup_schema ] && prep_for_mysql_dbsync

	# store the refreshdelay variable in a file for parallel to read
	echo "$refreshdelay" > $dir/refreshdelay

	if [ "$(echo $realresellers)" ]; then #use echo to avoid false positive on whitespace
		# run resellers first if there are any
		ec yellow "Running $(cat $dir/realresellers.txt | wc -w) resellers first..."
		parallel --jobs $jobnum -u 'packagefunction {#} {} >$dir/log/looplog.{}.log' ::: $realresellers &
		syncprogress $!
		remainingusers=$(cat $dir/nonresellers.txt)
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
