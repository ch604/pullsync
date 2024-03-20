backup_check() { #detect if backups are enabled and optionally turn them on
	ec yellow "Checking backup configuration..."
	# print is this a storm server, usually you do not want cp backups.
	if df | awk '{print $1}' | grep -qE 'vda[0-9]'; then
		ec lightBlue "This appears to be a Storm Server."
	else
		ec blue "This appears to be a Dedicated Server."
	fi

	# need to ensure backups are on and accounts are set to be backed up
	backup_enable=$(/usr/local/cpanel/bin/whmapi1 backup_config_get | awk '/backupenable/ {print $2}')
	backup_acct=$(/usr/local/cpanel/bin/whmapi1 backup_config_get | awk '/backupaccts/ {print $2}')
	remote_backups=$(awk -F\' '/^BACKUPENABLE:/ {print $2}' $dir/var/cpanel/backups/config)
	if [ "$remote_backups" = "yes" ]; then
		ec lightGreen "Remote cPanel backups are enabled."
		if [ "$(ls $dir/var/cpanel/backups/*.backup_destination 2> /dev/null)" ]; then
			ec red "Remote server has a remote backup destination (s3)!" | errorlogit 3
			say_ok
		fi
		if [ -f "$dir/usr/local/lp/etc/lp-UID" ] && awk '{print $2}' "$dir/etc/fstab" | grep -q /backup; then #source is lw and there is a backup mount point
			if sssh "df" | awk '{print $1}' | grep -qE 'vdb[0-9]'; then
				ec red "Remote server appears to have a Block Storage Device and a mount for /backup! If target is a storm server, you might want to bring this over." | errorlogit 4
				say_ok
			elif ! sssh "df" | awk '{print $1}' | grep -qE 'vda[0-9]'; then
				ec red "Source server appears to be a dedicated server and has a mount point for /backup! If target is a storm server, consider adding a Block Storage Device, if there isn't one already." | errorlogit 4
				say_ok
			fi
		fi
	else
		ec white "Remote cPanel backups are disabled."
	fi

	if [ "$backup_enable" = 1 ] && [ "$backup_acct" = 1 ]; then
		ec lightGreen "Local cPanel backups are enabled."
	else
		ec white "Local cPanel backups are disabled."
		mkdir -p /backup # needs to exist for next df command
		ec yellow "/backup has $(df -Ph /backup | tail -n1 | awk '{print $5 " usage (" $3 " of " $2 ") and is mounted on " $6}')."
		ec yellow "If enabled, the following settings would be in place on the local server:"
		/usr/local/cpanel/bin/whmapi1 backup_config_get | grep -E '(backup_daily|backup_monthly|backup_weekly|backupdays)' | logit
		ec yellow "The remote server has the following backup schedule:"
		grep -E '(BACKUP_DAILY|BACKUP_MONTHLY|BACKUP_WEEKLY|BACKUPDAYS)' "$dir/var/cpanel/backups/config" | logit
		if [ ! "$autopilot" ]; then
			if yesNo "Do you want to enable cPanel backups?"; then
				# turn on backups
				/usr/local/cpanel/bin/whmapi1 backup_config_set backupenable=1 backupaccts=1 2>&1 | stderrlogit 3
				enabledbackups=1
				if yesNo "Do you want to copy the remote backup schedule?"; then
					# copy over the backup config file
					mv /var/cpanel/backups/config{,.pullsync}
					cp -a "$dir/var/cpanel/backups/config" /var/cpanel/backups/
					rm -f /var/cpanel/backups/config.cache
					ec green "Done!"
				fi
			fi
#		elif [ "$autopilot" ] && [ $do_installs ]; then
			# disabled automatically turning on backups in case of storm server or no backup disk
#			/usr/local/cpanel/bin/whmapi1 backup_config_set backupenable=1 backupaccts=1 2>&1 | stderrlogit 3
#			enabledbackups=1
		fi
	fi
}
