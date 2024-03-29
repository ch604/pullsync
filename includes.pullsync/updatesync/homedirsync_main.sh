homedirsync_main() { #wraps up the homedir sync function into finalprogress so you get a progress display
	# get some input for the process progress bars
	multihomedir_check
	space_check

	local cmd=(dialog --nocancel --clear --backtitle "pullsync" --title "Homedir Sync Menu" --separate-output --checklist "Select options for the homedir sync." 0 0 5)
	local options=( 1 "Use --update for rsync" on
			2 "Exclude 'cache' from the rsync" off )
	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	echo $choices >> $log
	for choice in $choices; do
		print_next_element options $choice >> $log
		case $choice in
			1) rsync_update="--update";;
			2) rsync_excludes=$(echo --exclude=cache $rsync_excludes);;
			*) :;;
		esac
	done

	misc_ticket_note

	# start unattended section
	lastpullsyncmotd

	# set variables for progress display
	user_total=$(echo $userlist | wc -w)
	start_disk=0
	homemountpoints=$(for each in $(echo $localhomedir); do findmnt -nT $each | awk '{print $1}'; done | sort -u)
	for each in $(echo $homemountpoints); do
		local z=$(df $each | tail -n1 | awk '{print $3}')
		start_disk=$(( $start_disk + $z ))
	done
	expected_disk=$(( $start_disk + $finaldiff ))

	# store the refreshdelay variable in a file for parallel to read
	echo "$refreshdelay" > $dir/refreshdelay

	parallel --jobs $jobnum -u 'rsync_homedir_wrapper {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
	finalprogress $! rsync_email
}
