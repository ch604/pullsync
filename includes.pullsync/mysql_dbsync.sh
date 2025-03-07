mysql_dbsync() { # syncs the database passed as $1. if the db doesnt exist, creates it and attempts to add grants. progress is passed if it is set.
	local db user mysqluser tables sqlsyncpid refreshdelay
	# get the passed variable
	db=$1
	# ensure mysql is running on source forever
	while ! sssh_sql admin status > /dev/null ; do
		ec lightRed "$progress Mysql does not seem to be running on remote server per 'mysqladmin status'! Attempting automatic restart..."
		sssh -n "/scripts/restartsrv_mysql"
		ec lightRed "$progress Sleeping for 10 before retry. If you see this a second time, please restart mysql on the source server manually..."
		sleep 10
		sssh_sql -e 'set global net_write_timeout=600; set global net_read_timeout=300' 2>&1 | stderrlogit 3
	done

	# make sure db actually exists on source, otherwise log and return
	if ! sssh_sql -e 'show databases;' | grep -qEx "$db"; then
		ec red "$progress Mysql db $db does not exist on source server! Can't copy what you can't find!" | errorlogit 2 root
		return
	fi

	if ! sql -e 'show databases;' | grep -qEx "$db"; then
		# create db if it does not exist, and copy its grants
		ec red "$progress Mysql db $db does not exist on this server! Creating and mapping..." | errorlogit 3 root
		echo "$db" >> "$dir/missing_dbs.txt"
		sql admin create "$db"
		user=$(sssh -n "grep -l \"$db\" /var/cpanel/databases/* 2> /dev/null" | grep -Ev '(dbindex.db|grants_|users.db)' | cut -d/ -f5 | cut -d. -f1 | sort -u | head -1)
		if [ "$user" ]; then
			/usr/local/cpanel/bin/dbmaptool "$user" --type mysql --dbs "$db"
		else
			ec red "$progress Couldn't detect user, skipping $db map"
		fi
		ec red "$progress Collecting grants..."
		mysqluser=$(sssh_sql -Nse "select user from mysql.db where db='${db//_/\\\\_}'" | grep -v -e "^$user$" -e "^root$" | sort -u | head -1)
		if [ "$mysqluser" ]; then
			sssh_sql -Nse "show grants for '$mysqluser'@'localhost'" | tee -a "$dir/missing_dbgrants.txt" | sql
			if [ "$user" ]; then
				/usr/local/cpanel/bin/dbmaptool "$user" --type mysql --dbusers "$mysqluser"
			else
				ec red "$progress Couldn't detect user, skipping $mysqluser map"
			fi
		else
			ec lightRed "$progress Couldn't collect grant for $db!" | errorlogit 3 root
		fi
	elif [ ! "$skipsqlzip" ]; then
		# if the db does exist, back it up and zip it
		ec blue "$progress Backing up $db to $dir/pre_dbdumps..."
		sql dump --opt --routines --add-drop-trigger "$db" | gzip > "$dir/pre_dbdumps/$db.sql.gz"
		chmod 600 "$dir/pre_dbdumps/$db.sql.gz"
	fi

	# enumerate tables
	tables=$(sssh_sql "$db" -Bse 'show tables')

	if [ "$tables" ]; then
		# there are tables for this database, we sync them
	ec purple "$progress Streaming dump of $db to target..."
		# shellcheck disable=SC2086
		parallel -j "$sqljobnum" -u "parallel_mysql_dbsync $db {}" ::: $tables &
		sqlsyncpid=$!
		while kill -0 $sqlsyncpid 2> /dev/null; do
			refreshdelay=$(cat "$dir/refreshdelay")
			[[ ! "$refreshdelay" =~ ^[0-9]+$ || "$refreshdelay" -gt 60 ]] && refreshdelay=3
			mysqlprogress "$db"
			sleep "$refreshdelay"
		done
		echo ""
		# if there are stored procedures/functions, sync them last
		if grep -qx "$db" "$dir/pre_dbdumps/routineslist.txt"; then
			ec purple "$progress Copying $db routines..."
			IFS=" " read -ra dumpstatus < <(sssh_sql dump -ntdR --add-drop-trigger "$db" 2>> "$dir/log/dbsync.log" | sed '1{/999999.*sandbox/d}' | sql "$db" 2>> "$dir/log/dbsync.log"; printf %s "${PIPESTATUS[*]}")
			if [ "${dumpstatus[0]}" -ne 0 ]; then
				# dump failed, retry
				IFS=" " read -ra dumpstatus < <(sssh_sql dump -ntdR --add-drop-trigger "$db" 2>> "$dir/log/dbsync.log" | sed '1{/999999.*sandbox/d}' | sql "$db" 2>> "$dir/log/dbsync.log"; printf %s "${PIPESTATUS[*]}")
				if [ "${dumpstatus[0]}" -ne 0 ]; then
					# second dump failed too, mark as failed
					ec lightRed "$progress Mysql routines for $db returned non-zero exit code. Might be corrupt." | errorlogit 3 root
					echo "$db ROUTINES" >> "$dir/dbdump_fails.txt"
				fi
			fi
		fi
	fi
	ec green "$progress $db complete!"
}
