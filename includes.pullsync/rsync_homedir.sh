rsync_homedir() { # $1 is user, $2 is progress. confirms restoration and rsyncs the homedir of a restored account. also executes malware_scan, phpfpm conversion, suspension, and perm fixes, as well as a few extra syncs for final syncs.
	local user progress userhome_remote userhome_local remote_quotaline remote_quota remote_inodes
	user=$1
	progress="$2 | $user:"
	if [ -f "$dir/etc/passwd" ]; then
		userhome_remote=$(awk -F: '/^'"$user"':/ {print $6}' "$dir/etc/passwd")
		userhome_local=$(eval echo ~${user})
		# check if cpanel user exists
		if [ -f "$dir/var/cpanel/users/$user" ] && [ -f "/var/cpanel/users/$user" ] && [ "$userhome_local" ] && [ "$userhome_remote" ] && [ -d "$userhome_local" ] && sssh "[ -d $userhome_remote ]"; then
			# comment out crons
			if [ "$synctype" != "final" ] && [ "$comment_crons" ] && [ -f "/var/spool/cron/$user" ]; then
				ec brown "$progress Commenting out crons for $user..."
				sed -i 's/^\([^#]\)/#\1/g' /var/spool/cron/$user
			fi

			# test for public_html symlink on non-final syncs
			if [ "$synctype" != "final" ]; then
				if sssh "[ -h $userhome_remote/public_html ]" && [ ! -h "$userhome_local/public_html" ]; then
					mkdir -p "$dir/public_html_symlink_baks/$user"
					mv "$userhome_local/public_html" "$dir/public_html_symlink_baks/$user/"
					ec brown "$progress Source public_html is symlink, moved $user's public_html to $dir/public_html_symlink_baks/$user/public_html." | errorlogit 4 "$user"
				fi
			fi
			# collect quotas for rsync status printing; always try repquota even if its not installed, this will be sorted when printing. get mountpoint of the userhome in case /home2.
			remote_quotaline=$(sssh "repquota -s \$(findmnt -nT $userhome_remote | awk '{print \$1}') 2> /dev/null" | grep ^${user}\ )
			remote_quota=$(echo $remote_quotaline | awk '{print $3}')
			remote_inodes=$(echo $remote_quotaline | awk '/+-|++/ {print $7;next} /--|-+/ {print $6}')
			ec lightGreen "$progress Rsyncing homedir (${remote_quota:-no quota} used with ${remote_inodes:-no inode quota} inodes)..."

			# perform file copies
			srsync $rsync_update $rsync_excludes --exclude=/mail/* $ip:$userhome_remote/ $userhome_local/ &> $dir/log/rsync.${user}.log
			[[ $? -ne 0 && $? -ne 24 ]] && ec red "$progress Rsync task for $user returned nonzero exit code! This may need to get resynced (cat $dir/log/rsync.${user}.log)!" | errorlogit 2 "$user"

			# optionally convert to FPM
			if [ "$fpmconvert" ]; then
				ec white "$progress Converting domains to PHP-FPM..."
				fpmconvert $user 1
			else
				ec white "$progress Ensuring php version for domains matches source..."
				fpmconvert $user 0
			fi

			# resync several items on final: crons, valiases, ftp accounts, system pass
			if [ "$synctype" = "final" ]; then
				[ -f $dir/var/spool/cron/$user ] && srsync $ip:/var/spool/cron/$user /var/spool/cron/
				[ -f /var/spool/cron/$user ] && chown $user:root /var/spool/cron/$user
				[ -f $dir/etc/proftpd/$user ] && rsync $rsyncargs $dir/etc/proftpd/$user /etc/proftpd/ 2>&1 | stderrlogit 3
				remotehash=$(sssh "grep ^$user\: /etc/shadow" | cut -d: -f1-2)
				if [ ! "${remotehash}" = "$(grep ^$user\: /etc/shadow | cut -d: -f1-2)" ]; then
					ec brown "$progress Linux password changed, updating on target..." | errorlogit 4 "$user"
					echo $remotehash | chpasswd -e 2>&1 | stderrlogit 3
				fi
				for dom in $(awk -F: '/ '${user}'$/ {print $1}' /etc/userdomains); do
					srsync $ip:/etc/valiases/$dom /etc/valiases/ --update 2>&1 | stderrlogit 4
				done
			fi

			# fixperms
			if [ $fixperms ]; then
				ec brown "$progress Fixing permissions..."
				sh /home/fixperms.sh $user 2>&1 | stderrlogit 4
			fi

			# malware scan
			[ $malwarescan ] && malware_scan $user

			# suspend suspended accounts
			if grep -q -E '^SUSPENDED[ ]?=[ ]?1' $dir/var/cpanel/users/$user; then
				ec brown "$progress User is suspended on source server, suspending on target..." | errorlogit 4 "$user"
				/scripts/suspendacct $user 2>&1 | stderrlogit 4
			fi
		else
			# restore failed
			ec red "Warning: Cpanel user $user homedir paths not found! Not rsycing homedir." | errorlogit 2 "$user"
		fi
	else
		# problem with remote files
		ec lightRed "Error: Password file from remote server not found at $dir/etc/passwd, can't sync homedir for $user! " | errorlogit 2 "$user"
		echo $user >> $dir/did_not_restore.txt
	fi
}
