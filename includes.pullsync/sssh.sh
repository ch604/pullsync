# shellcheck disable=SC2029,SC2086
sssh() { #super ssh, accepts all arguments as remote commands. pass the exitcode back to the original pipeline.
	local EXITCODE
	# ssh with appropriate flags, using all arguments as a remote command
	ssh $sshargs root@$ip "$@"
	EXITCODE=$?
	if [ $EXITCODE -eq 255 ]; then
		# the connection failed (255, otherwise we would have the remote command exit code)
		echo "ssh connection failed. retrying once more after 15s..."
		sleep 15
		ssh $sshargs root@$ip "$@"
		EXITCODE=$?
	fi
	# pass the remote command exit code back to the original command
	return "${EXITCODE:-255}"
}
