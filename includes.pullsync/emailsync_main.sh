emailsync_main() { #wraps up the email sync function into finalprogress so you get a progress display
	# get some input for the process progress bars
	multihomedir_check
	space_check

	if yesNo "Use --update for rsync?"; then
		rsync_update="--update"
	fi

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

	parallel --jobs $jobnum -u 'rsync_email {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
	finalprogress $! rsync_email
}
