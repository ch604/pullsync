cpbackup_finish() { #if enabled in backupcheck(), toggle on backups for user passed as $1
	[ "$(/usr/local/cpanel/bin/whmapi1 accountsummary user="$1" | awk '/ backup:/ {print $2}')" -ne 1 ] && /usr/local/cpanel/bin/whmapi1 toggle_user_backup_state user="$1" 2>&1 | stderrlogit 3
}
