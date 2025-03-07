sssh() { #super ssh, accepts all arguments as remote commands. pass the exitcode back to the original pipeline.
	# ssh with appropriate flags, using all arguments as a remote command
	ssh ${sshargs} ${ip} $@
	EXITCODE=$?
	if [ $EXITCODE -eq 255 ]; then
		# the connection failed (255, otherwise we would have the remote command exit code)
		echo "ssh connection failed. retrying once more after 15s..."
		sleep 15
		ssh ${sshargs} ${ip} $@
		EXITCODE=$?
		# if we fail this time, just let it go
	fi
	# pass the remote command exit code back to the original command
	return $EXITCODE
}
