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
	getreadyforparallel

	ec yellow "Executing email sync..."
	parallel --jobs $jobnum -u 'rsync_email_wrapper {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
	syncprogress $! rsync_email_wrapper
}
