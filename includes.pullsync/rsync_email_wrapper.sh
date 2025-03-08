rsync_email_wrapper() { # $1 is progress position, $2 is user. rsync just the mail folders. used to confirm variables and provide output when used as an update sync type.
	local user progress userhome_remote userhome_local
	user=$2
	progress="$1/$user_total | $user:"
	if [ -f "$dir/etc/passwd" ]; then
		userhome_remote=$(awk -F: '/^'$user':/ {print $6}' $dir/etc/passwd)
		userhome_local=$(eval echo ~${user})
		# check if cpanel user exists
		if [ -f $dir/var/cpanel/users/$user ] && [ -f /var/cpanel/users/$user ] && [ "$userhome_local" ] && [ "$userhome_remote" ] && [ -d "$userhome_local" ] && sssh "[ -d $userhome_remote ]"; then
			ec lightGreen "$progress Syncing files..."
			# copy the folders
			rsync_email $user 0
			# sync forwarders
			while read -r dom; do
				srsync $rsync_excludes "$ip":"/etc/valiases/$dom" /etc/valiases/
			done < <(awk -F= '/^DNS[0-9]*=/ {print $2}' "$dir/var/cpanel/users/$user")
			# write to eternal log
			eternallog "$user"
			echo "$user" >> "$dir/final_complete_users.txt"
		else
			ec red "Warning: Cpanel user $user not found! Not rsycing." | errorlogit 2 "$user"
			echo "$user" >> "$dir/did_not_restore.txt"
		fi
	else
		# problem with files from remote server
		ec lightRed "Error: Password file from remote server not found at $dir/etc/passwd, can't sync email for $user!"
		echo "$user" >> "$dir/did_not_restore.txt"
	fi
}
