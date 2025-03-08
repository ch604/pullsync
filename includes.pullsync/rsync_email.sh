rsync_email() { # $1 is user to be synced, $2 is the --delete option. runs $mailjobnum maildir rsyncs in parallel. should perform no output to screen.
	local user d userhome_remote userhome_local mailboxlist
	user=$1
	[ "$2" -eq 1 ] && d="--delete"
	userhome_remote=$(awk -F: '/^'"$user"':/ {print $6}' "$dir/etc/passwd")
	userhome_local=$(eval echo ~${user})

	mailboxlist=$(user_email_listgen "$user")

	if [ "$mailboxlist" ]; then
		for each in $mailboxlist; do
			mkdir -p "$userhome_local/$each" &> /dev/null
			chown "$user":"$user" "$userhome_local/$each"
		done
		# shellcheck disable=SC2086
		parallel -j "$mailjobnum" -u "srsync $rsync_update $ip:$userhome_remote/{}/ $userhome_local/{} $d &> $dir/log/${user}.rsync.log; [[ \$? -ne 0 && \$? -ne 24 ]] && echo \"[ERROR] Mail sync task for {} returned nonzero exit code, this may need to be resynced (cat $dir/log/$user.rsync.log)\" >> $dir/error.log; echo {} >> $dir/log/$user.mail.log" ::: $mailboxlist
	fi
	if sssh [ -d "$userhome_remote/mail" ]; then
		srsync "$rsync_update" "$ip":"$userhome_remote/mail" "$userhome_local/" $d &> "$dir/log/$user.rsync.log"
		[[ "$?" -ne 0 && "$?" -ne 24 ]] && echo "[ERROR] Mail sync task for $user returned nonzero exit code, this may need to be resynced (cat $dir/log/$user.rsync.log)" >> "$dir/error.log"
	fi
	if sssh [ -d "$userhome_remote/etc" ]; then
		srsync "$rsync_update" "$ip":"$userhome_remote/etc" "$userhome_local/" $d &> "$dir/log/$user.rsync.log"
		[[ "$?" -ne 0 && "$?" -ne 24 ]] && echo "[ERROR] Mail sync task for $user returned nonzero exit code, this may need to be resynced (cat $dir/log/$user.rsync.log)" >> "$dir/error.log"
	fi
}
