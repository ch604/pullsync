rsync_email() { # $1 is progress position, $2 is user. rsync just the mail folders.
	# set local variables to avoid collision with other parallel procs
	local user=$2
	local progress="$1/$user_total | $user:"
	if [ -f "$dir/etc/passwd" ]; then
		local userhome_remote=`grep ^$user: $dir/etc/passwd | tail -n1 |cut -d: -f6`
		local userhome_local=`eval echo ~${user}`
		# check if cpanel user exists
		if [ -f $dir/var/cpanel/users/$user ] && [ -f /var/cpanel/users/$user ] && [ $userhome_local ] && [ $userhome_remote ] && [ -d $userhome_local ] && sssh "[ -d $userhome_remote ]"; then
			ec lightGreen "$progress Rsyncing email..."
			# copy the folder
			rsync $rsyncargs --bwlimit=$rsyncspeed $rsync_update $rsync_excludes -e "ssh $sshargs" ${ip}:${userhome_remote}/mail :${userhome_remote}/etc $userhome_local/
			# sync forwarders
			for dom in $(grep -e ^DNS[0-9]*= $dir/var/cpanel/users/$user | cut -d= -f2); do
				rsync $rsyncargs --bwlimit=$rsyncspeed $rsync_update $rsync_excludes -e "ssh $sshargs" ${ip}:/etc/valiases/$dom /etc/valiases/
			done
			# write to eternal log
			eternallog $user
		else
			ec red "Warning: Cpanel user $user not found! Not rsycing." | errorlogit 2
			echo $user >> $dir/did_not_restore.txt
		fi
	else
		# problem with files from remote server
		ec lightRed "Error: Password file from remote server not found at $dir/etc/passwd, can't sync email for $user! "
		echo $user >> $dir/did_not_restore.txt
	fi
}
