cpbackup_finish() { #if enabled in backupcheck(), toggle on backups for all users
	ec yellow "Finishing configuration of cPanel backups..."
	for user in $userlist; do
		# check the accountsummary and if backup is not 1, toggle it via whmapi
		[ ! $(/usr/local/cpanel/bin/whmapi1 accountsummary user=$user | grep \ backup\: | awk '{print $2}') -eq 1 ] && /usr/local/cpanel/bin/whmapi1 toggle_user_backup_state user=$user 2>&1 | stderrlogit 3
	done
}
