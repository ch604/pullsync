finalfunction() { #$1 is position, $2 is username. this is where the actual final sync happens. programmed with global variables and argument import so it can be looped in parallel.
	local user progress mailinglists
	user=$2
	progress="$1/$user_total | $user:"
	#get some rare stuff out of the way first
	if [ "$dopgsync" ]; then
		pglist=$(user_pgsql_listgen "$user")
		if [ "$pglist" ]; then
			for db in $pglist; do
				ec blue "$progress | $user: Importing pgsql db $db..."
				pgsql_dbsync "$db" "$user"
			done
		fi
	fi
	if [ -f "/var/cpanel/datastore/$user/mailman-list-usage" ] && [ "$(cat "/var/cpanel/datastore/$user/mailman-disk-usage")" -gt 0 ]; then
		mailinglists=$(cut -d: -f1 "/var/cpanel/datastore/$user/mailman-list-usage")
		ec white "$progress Syncing mailman lists..."
		for list in $mailinglists; do
			# list settings in /usr/local/cpanel/3rdparty/mailman/lists/$list
			srsync "$ip":"/usr/local/cpanel/3rdparty/mailman/lists/$list" /usr/local/cpanel/3rdparty/mailman/lists/
			# archive data is in /usr/local/cpanel/3rdparty/mailman/archives/{private,public}/$list{,.mbox}
			srsync "$ip":"/usr/local/cpanel/3rdparty/mailman/archives/private/$list" :"/usr/local/cpanel/3rdparty/mailman/archives/private/$list.mbox" /usr/local/cpanel/3rdparty/mailman/archives/private/
			srsync "$ip":"/usr/local/cpanel/3rdparty/mailman/archives/public/$list" :"/usr/local/cpanel/3rdparty/mailman/archives/public/$list.mbox" /usr/local/cpanel/3rdparty/mailman/archives/public/ 2>&1 | stderrlogit 4
		done
	fi
	#the meaty core
	sem --id "datamove$user" -j 3 -u mysql_dbsync_user "$user" "$progress" >> "$dir/log/$user.db.log"
	sem --id "datamove$user" -j 3 -u rsync_homedir "$user" "$progress"
	sem --id "datamove$user" -j 3 -u rsync_email "$user" "${maildelete:-0}"
	sem --wait --id "datamove$user"
	echo "$user" >> "$dir/final_complete_users.txt"
}
