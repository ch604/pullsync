backup_check() { #detect if backups are enabled and optionally turn them on
	ec yellow "Checking backup configuration..."
	# print is this a virtual server, usually you do not want cp backups.
	if lscpu | grep -q ^Hypervisor\ vendor; then
		ec lightBlue "This appears to be a virtual Server."
	else
		ec blue "This appears to be a dedicated Server."
	fi

	# need to ensure backups are on and accounts are set to be backed up
	backup_enable=$(/usr/local/cpanel/bin/whmapi1 backup_config_get | grep backupenable | awk '{print $2}')
	backup_acct=$(/usr/local/cpanel/bin/whmapi1 backup_config_get | grep backupaccts | awk '{print $2}')
	remote_backups=$(grep ^BACKUPENABLE: "$dir/var/cpanel/backups/config" | cut -d\' -f2)
	local sourcebackupdir=$(grep ^BACKUPDIR: "$dir/var/cpanel/backups/config" | awk '{print $2}'
	if [ "$remote_backups" = "yes" ]; then
		ec lightGreen "Remote cPanel backups are enabled."
		if [ "$(ls $dir/var/cpanel/backups/*.backup_destination 2> /dev/null)" ]; then
			ec red "Remote server has a remote backup destination (s3, ftp, etc)!" | errorlogit 3
			say_ok
		fi
		if awk '{print $2}' "$dir/etc/fstab" | grep -q $sourcebackupdir; then #source has a backup mount point
			ec red "Source server has a separate mount point for $sourcebackupdir!" | errorlogit 4
		fi
	else
		ec while "Remote cPanel backups are disabled."
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
			# disabled automatically turning on backups in case of no backup disk
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
		fi
	fi
}
