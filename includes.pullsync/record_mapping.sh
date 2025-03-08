record_mapping() { #write mapping files at the hands-off breakpoint, user passed as $1
	local user userhome_remote userhome_local mailboxlist dblist
	user=$1
	#homedir; only written on non-initial syncs since we cant map to a blank target, and would be populated as accounts restore in those cases
	if ! echo -e "single\nlist\ndomainlist\nall\nskeletons" | grep -qx $synctype; then
		userhome_remote=$(awk -F: '/^'$user':/ {print $6}' $dir/etc/passwd)
		userhome_local=$(eval echo ~${user})
		echo "$user $userhome_remote $userhome_local" >> $dir/mapping.homedir.tsv
	fi
	#email
	mailboxlist=$(user_email_listgen $user)
	[ "$mailboxlist" ] && for path in $mailboxlist; do
		echo "$user $path" >> $dir/mapping.email.tsv
	done
	#dbs
	dblist=$(user_mysql_listgen $user)
	[ -f /root/db_exclude.txt ] && dblist=$(echo "$dblist" | grep -vx -f /root/db_exclude.txt)
	[ "$dblist" ] && for db in $dblist; do
		echo "$user $db" >> $dir/mapping.db.tsv
	done
}
