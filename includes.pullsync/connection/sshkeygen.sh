sshkeygen() { #generate a unique ssh key and copy it to the source server.
	# make connections to source easier
	whitelist_source
	multiplex

	if [ "$autopilot" ]; then
		# set up the passed keyfile. no need to initially copy it, since it should already be on source.
		[ ! "$keyfile" ] && ec red "I SAID, -k is a required option for autopilot!!" && exitcleanup 9
		if [ -f "$keyfile" ]; then
			chmod 600 $keyfile
			echo "$keyfile" > $dir/keyname.txt
			sshargs="$sshargs -i $keyfile -p$port -oStrictHostKeyChecking=no" #disable yes/no check
			echo "$port" > $dir/port.txt
		else
			ec red "It looks like $keyfile isn't a file... Please provide the FULL PATH to a functioning PRIVATE SSH KEY"
			exitcleanup 9
		fi
	else
		# generate a key
		mkdir -p -m600 /root/.ssh
		[ -f /root/.ssh/pullsync*.pub ] && rm -f /root/.ssh/pullsync*
		keyname=pullsync.$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
		ec yellow "Generating SSH key /root/.ssh/${keyname}..."
		ssh-keygen -q -N "" -t rsa -f /root/.ssh/${keyname} -C "${keyname}"
		echo "/root/.ssh/${keyname}" > $dir/keyname.txt
		# print sshkey and pause before trying ssh connection.
		ec lightCyan "Generated ssh key. Run this command on the source server if you want to skip typing the remote password in this machine:"
		echo "echo \"$(cat ~/.ssh/${keyname}.pub)\" >> /root/.ssh/authorized_keys" | logit
		ec lightCyan "Press enter to attempt ssh connection to $ip."
		rd
		ec yellow "Copying Key to remote server..."
		sshargs="$sshargs -i /root/.ssh/${keyname}"
		# Cent4 is missing ssh-copy-id, Cent7 has a different version of ssh-copy-id that isn't backwards compatable with the one in 5/6, just use 'cat' method.
		cat ~/.ssh/${keyname}.pub | sssh "mkdir -p -m600 ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"
	fi

	# ensure that the conneciton works
	ec yellow "Testing ssh connection..."
	if ! ssh -oConnectTimeout=10 $sshargs $ip "true" ; then
		# connection failed, allow retry
		[ "$autopilot" ] && ec lightRed "SSH connection to $ip failed. Is the public key added to the target server?" && exitcleanup 9
		ec lightRed "Error: Ssh connection to $ip failed or timed out."
		ec yellow "May need to change 'PermitRootLogin no' to 'PermitRootLogin without-password' in sshd_config on remote server."
		ec yellow "Also check PasswordAuthentication in sshd_config, /etc/security/access.conf, software firewall deny list, or /etc/hosts.allow."
		ec lightCyan "Add pubkey from ~/.ssh/${keyname}.pub below to remote server, and press enter to retry"
		cat ~/.ssh/${keyname}.pub
		rd
		if ! ssh -oConnectTimeout=10 $sshargs $ip "true" ; then
			# fail here if we were unable to connect to the remote server.
			ec lightRed "Error: Ssh connection to $ip failed, please check connection before retrying!" | errorlogit 1
			exitcleanup 3
		fi
	fi

	echo $ip > $dir/ip.txt #output to ip.txt only after ssh connection success, for control_c support
	ec green "Ssh connection to $ip succeeded!"
	# command to remove the 'stdin: is not a tty' error. prepend to /root/.bashrc on the source server. don't add more entries if it exists.
	stdin_cmd="if ! grep -q '\[ -z "'$PS1'" \] && return' /root/.bashrc; then sed -i '1s/^/[ -z "'$PS1'" ] \&\& return\n/' /root/.bashrc; fi"
	sssh "$stdin_cmd"
	sleep 0.5
	# if we arent root, bail
	[ $(sssh "id -u") -ne 0 ] && ec red "You don't seem to be root on source... I got UID $(sssh "id -u")" && exitcleanup 99
	# if source is not a cpanel server, bail
	sssh "[ ! -f /etc/wwwacct.conf ]" && ec red "Source server doesn't seem to be a cPanel server..." && exitcleanup 99
	# disable firewall app for hostgator servers, it denies rapid remote connections
	sssh "[ \$(which firewall 2>/dev/null) ] && firewall stop"
	# make a remote tempdir and record some critical info
	sssh "mkdir -p -m600 $remote_tempdir/"
	echo -e "target server: $(hostname)-${cpanel_main_ip}\nstarted by: ${sshClientIP}" | sssh "cat > $remote_tempdir/syncinfo.txt"
}
