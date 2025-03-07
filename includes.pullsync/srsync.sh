# shellcheck disable=SC2086
# super rsync, like sssh, passes arguments to rsync and tests exit code for failure. retries if theres a failure other than vanished file (24).
srsync() {
	local exitcode
	rsync $rsyncargs -e "ssh $sshargs" --bwlimit="$rsyncspeed" "$@"
	exitcode=$?
	if [ "$exitcode" -ne 0 ] && [ "$exitcode" -ne 24 ]; then
		echo "rsync failed with exit code $exitcode, retrying once more after 10s..." 1>&2
		sleep 10
		rsync $rsyncargs -e "ssh $sshargs" --bwlimit="$rsyncspeed" "$@"
		exitcode=$?
	fi
	return "$exitcode"
}