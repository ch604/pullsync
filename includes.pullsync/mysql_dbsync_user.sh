mysql_dbsync_user(){ # syncs the databases for the user passed as $1. if the db doesnt exist, creates it and attempts to add grants. progress as #/# is passed as $2.
	local user progress dblist db_count _j dbprog mysqluser tables
	declare -a dumpstatus
	# get the passed variable
	user=$1
	progress="$2 | $user:"
	# ensure mysql is running on source forever
	while ! sssh_sql admin status > /dev/null ; do
		ec lightRed "$progress Mysql does not seem to be running on remote server per 'mysqladmin status'! Attempting automatic restart..."
		sssh -n "/scripts/restartsrv_mysql"
		ec lightRed "$progress Sleeping for 10 before retry. If you see this a second time, please restart mysql on the source server manually..."
		sleep 10
		sssh_sql -e "set global net_write_timeout=600; set global net_read_timeout=300" 2>&1 | stderrlogit 3
	done

	# make the list of dbs for this user
	dblist=$(user_mysql_listgen "$user")
	[ -f /root/db_exclude.txt ] && dblist=$(grep -vx -f /root/db_exclude.txt <<< "$dblist")
	db_count=$(wc -l <<< "$dblist")
	_j=1

	for db in $dblist; do
		dbprog="$_j/$db_count"
		# make sure db actually exists on source, otherwise log, increment, and continue rest of for loop
		if ! sssh_sql -e 'show databases;' | grep -qEx "$db"; then
			ec red "$progress Mysql db $db ($dbprog) does not exist on source server! Can't copy what you can't find!" | errorlogit 2 "$user"
			(( _j+=1 ))
			continue
		fi
		# create db if it does not exist, and copy its grants
		if ! sql -e 'show databases;' | grep -qEx "${db}"; then
			ec red "$progress Mysql db $db ($dbprog) does not exist on this server! Creating and mapping..." | errorlogit 3 "$user"
			echo "$db" >> "$dir/missing_dbs.txt"
			sql admin create "$db"
			/usr/local/cpanel/bin/dbmaptool "$user" --type mysql --dbs "$db"
			ec red "$progress Collecting grants..."
			mysqluser=$(sssh_sql -Nse "select user from mysql.db where db='${db//_/\\\\_}'" | grep -v -e "^$user$" -e "^root$" | sort -u | head -1)
			if [ "$mysqluser" ]; then
				sssh_sql -Nse "show grants for '$mysqluser'@'localhost'" | tee -a "$dir/missing_dbgrants.txt" | sql
				/usr/local/cpanel/bin/dbmaptool "$user" --type mysql --dbusers "$mysqluser"
			else
				ec lightRed "$progress Couldn't collect grant for $db ($dbprog)!" | errorlogit 3 "$user"
			fi
		elif [ ! "$skipsqlzip" ]; then
			# if the db does exist, back it up and zip it
			ec blue "$progress Backing up $db ($dbprog) to $dir/pre_dbdumps..."
			sql dump --opt --routines --add-drop-trigger "$db" | gzip > "$dir/pre_dbdumps/$db.sql.gz"
			chmod 600 "$dir/pre_dbdumps/$db.sql.gz"
		fi

		# enumerate tables
		tables=$(sssh_sql "$db" -Bse 'show tables')

		# perform the data sync if there are any tables
		if [ "$tables" ]; then
			ec purple "$progress Streaming dump of $db ($dbprog) to target..."
			# shellcheck disable=SC2086
			parallel -j "$sqljobnum" -u "parallel_mysql_dbsync $db {}" ::: $tables
			if grep -q "^$db." "$dir/dbdump_fails.txt" 2> /dev/null; then
				#there were errors, log them as needed
				ec lightRed "$progress some tables failed to dump for $db, please investigate and resync as needed (grep \"^$db.\" $dir/dbdump_fails.txt)" | errorlogit 2 "$user"
			fi
			# if there are stored procedures/functions, sync them last
			if grep -qx "$db" "$dir/pre_dbdumps/routineslist.txt"; then
				ec purple "$progress Copying $db ($dbprog) routines..."
				IFS=" " read -ra dumpstatus < <(sssh_sql dump -ntdR --add-drop-trigger "$db" 2>> "$dir/log/dbsync.log" | sed '1{/999999.*sandbox/d}' | sql "$db" 2>> "$dir/log/dbsync.log"; printf %s "${PIPESTATUS[*]}")
				if [ "${dumpstatus[0]}" -ne 0 ]; then
					# dump failed, retry
					IFS=" " read -ra dumpstatus < <(sssh_sql dump -ntdR --add-drop-trigger "$db" 2>> "$dir/log/dbsync.log" | sed '1{/999999.*sandbox/d}' | sql "$db" 2>> "$dir/log/dbsync.log"; printf %s "${PIPESTATUS[*]}")
					if [ "${dumpstatus[0]}" -ne 0 ]; then
						# second dump failed too, mark as failed
						ec lightRed "$progress Mysql routines for $db returned non-zero exit code. Might be corrupt." | errorlogit 3 "$user"
						echo "$db ROUTINES" >> "$dir/dbdump_fails.txt"
					fi
				fi
			fi
		fi
		((_j+=1))
	done
	ec green "$progress All databases complete!"
}
