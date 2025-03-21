automain() { #the main menu for cli flag users. starts unattended basic migration using safer sane defaults.
	# empty your mind
	clear
	# print some basic info
	ec white "$scriptname
version: $version
Started at $starttime
"
	ec red "Starting unattended migration!"
	# should already have ip and port, but they need to get checked and recorded
	if [ "$oldip" ]; then
		ip=$oldip
		[ "$oldport" ] && port=$oldport
		getport
	else
		getip
		getport
	fi
	# connect to source
	sshkeygen
	ec yellow "Transferring some config files over from old server to $dir"
	# shellcheck disable=SC2046
	srsync -RL $ip$(for i in $filelist; do echo -n ":$i "; done) $dir/ --exclude=named.run --exclude=named.log --exclude=named.log-*.gz --exclude=chroot --delete 2>&1 | stderrlogit 4
	# verify valid userlist
	getuserlist
	case $synctype in
		final)
			dnsclustering
			cpnat_check
			dnscheck
			finalsync_main
			;;
		list|all)
			getversions
			lower_ttls
			initialsync_main
			;;
	esac
	finish_up
	exitcleanup
}
