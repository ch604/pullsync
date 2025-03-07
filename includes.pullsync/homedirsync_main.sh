homedirsync_main() { #wraps up the homedir sync function into finalprogress so you get a progress display
	local choices
	declare -a cmd options
	# get some input for the process progress bars
	multihomedir_check
	space_check

	cmd=(dialog --nocancel --clear --backtitle "pullsync" --title "Homedir Sync Menu" --separate-output --checklist "Select options for the homedir sync." 0 0 5)
	options=( 1 "Use --update for rsync" on
			2 "Exclude 'cache' from the rsync" off
			3 "Use --delete on the mail folder" off )
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	echo $choices >> $log
	for choice in $choices; do
		print_next_element options $choice >> $log
		case $choice in
			1) rsync_update="--update";;
			2) rsync_excludes=$(echo --exclude=cache $rsync_excludes);;
			3) maildelete=1;;
			*) :;;
		esac
	done

	misc_ticket_note

	# start unattended section
	lastpullsyncmotd
	getreadyforparallel

	ec yellow "Executing homedir sync..."
	parallel --jobs $jobnum -u 'rsync_homedir_wrapper {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
	syncprogress $! rsync_homedir_wrapper
}
