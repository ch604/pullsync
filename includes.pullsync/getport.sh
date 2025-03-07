getport() { #read and validate source port
	# next two lines will be skipped if port is already set from oldmigrationcheck()
	[ -z $port ] && echo "SSH Port [22]: " | logit && rd port
	[ -z $port ] && echo "No port given, assuming 22" | logit && port=22
	while [[ ! $port =~ $valid_port_format ]]; do
		echo "Invalid format, please re-enter source port:" | logit
		rd port
	done
	echo $port > $dir/port.txt
	sshargs="$sshargs -p$port"
}
