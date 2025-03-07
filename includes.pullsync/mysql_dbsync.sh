mysql_dbsync(){ # syncs the database passed as $1. if the db doesnt exist, creates it and attempts to add grants. progress is passed if it is set.
	# get the passed variable
	local db="$1"
	# ensure mysql is running on source forever
	while ! ssh ${sshargs} -n ${ip} "mysqladmin status > /dev/null" ; do # check if mysql is running using a more universal method
		ec lightRed "$progress Mysql does not seem to be running on remote server per 'mysqladmin status'! Attempting automatic restart..."
		ssh ${sshargs} -n ${ip} "[ -f /etc/init.d/mysql ] && /etc/init.d/mysql restart || service mysql restart"
		ec lightRed "$progress Sleeping for 10 before retry. If you see this a second time, please restart mysql on the source server manually..."
		sleep 10
		ssh ${sshargs} -n ${ip} "mysql -e 'set global net_write_timeout=600'; mysql -e 'set global net_read_timeout=300'" 2>&1 | stderrlogit 3
	done

	# make sure db actually exists on source, otherwise log and return
	if [ ! "$(sssh "mysql -e 'show databases;'" | egrep -x "${db}")" ]; then
		ec red "$progress Mysql db $db does not exist on source server! Can't copy what you can't find!" | errorlogit 2
		return
	fi

	if [ ! "$(mysql -e 'show databases;' | egrep -x "${db}")" ]; then
		# create db if it does not exist, and copy its grants
		ec red "$progress Mysql db $db does not exist on this server! Creating and mapping..." | errorlogit 3
		echo "$db" >> $dir/missing_dbs.txt
		mysqladmin create "$db"
		local user=$(ssh ${sshargs} -n ${ip} "grep -l \"$db\" /var/cpanel/databases/* 2> /dev/null | egrep -v '(dbindex.db|grants_|users.db)' | cut -d\/ -f5 | cut -d. -f1 | uniq")
		[ "$user" ] && /usr/local/cpanel/bin/dbmaptool $user --type mysql --dbs "$db" || ec red "$progress Couldn't detect user, skipping $db map"
		ec red "$progress Collecting grants..."
		local mysqluser=$(egrep \`$(echo "$db" | sed -e 's/_/\\\\_/')\` $dir/pre_dbdumps/mysql.grants.remote.sql | grep -v \'$user\' | cut -d\' -f2 | uniq | head -1)
		if [ "$mysqluser" ]; then
			grep \'$mysqluser\'@\'localhost\' $dir/pre_dbdumps/mysql.grants.remote.sql | grep -v \'root\' | tee -a $dir/missing_dbgrants.txt | mysql
			[ "$user" ] && /usr/local/cpanel/bin/dbmaptool $user --type mysql --dbusers "$mysqluser" || ec red "$progress Couldn't detect user, skipping $mysqluser map"
		else
			ec lightRed "$progress Couldn't collect grant for $db!" | tee -a $dir/missing_dbgrants.txt
		fi
	elif [ ! "$skipsqlzip" ]; then
		# if the db does exist, back it up and zip it
		ec blue "$progress Backing up ${db} to $dir/pre_dbdumps..."
		mysqldump --opt --routines --add-drop-trigger "$db" | gzip > "$dir/pre_dbdumps/${db}.sql.gz"
		chmod 600 "$dir/pre_dbdumps/${db}.sql.gz"
	fi

	# dump routines first
	local DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump -ntdR --add-drop-trigger \"$db\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
	declare -a status=( ${DUMP##*:} )
	if [ ! "${status[0]}" = "0" ]; then
		# dump failed, retry
		DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump -ntdR --add-drop-trigger \"$db\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
		declare -a status=( ${DUMP##*:} )
		if [ ! "${status[0]}" = "0" ]; then
			# second dump failed too, mark as failed
			ec lightRed "$progress routines for $db returned non-zero exit code. Might be corrupt." | errorlogit 3
			echo "${status[@]}"
			tail -n3 $dir/log/dbsync.log
			echo "$db ROUTINES" >> $dir/dbdump_fails.txt
		fi
	fi

	# enumerate tables
	local tables=$(sssh "mysql \"$db\" -Bse 'show tables'")
	local table_count=$(echo "$tables" | wc -l)
	local n=1

	# perform the data sync if there are any tables
	[ "$tables" ] && echo "$tables" | while read tb; do
		local tableprog="$n/$table_count"
		ec purple "$progress Streaming dump of $db.$tb ($tableprog) to target..."
		# perform the dump in a subshell to collect the pipestatus, getting exit code for the dump and the import at the same time
		if [ "$nodbscan" ]; then
			local DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump $mysqldumpopts \"$db\" \"$tb\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
		else
			local DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump $mysqldumpopts \"$db\" \"$tb\"" 2>> $dir/log/dbsync.log | tee >(dbscan) | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
		fi
		# turn the pipestatus into a usable array
		declare -a status=( ${DUMP##*:} )

		# parse the status to see if anything failed
		if [ ! "${status[0]}" = "0" ]; then
			# dump failed, retry without dbscan
			ec red "$progress Dump of $db.$tb returned non-zero exit code!"
			echo "${status[@]}"
			tail -n3 $dir/log/dbsync.log
			ec red "$progress Retrying dump of $db.$tb ($tableprog) without dbscan..."
			DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump $mysqldumpopts \"$db\" \"$tb\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
			if [ ! "${status[0]}" = "0" ]; then
				# second dump failed too, mark as failed
				ec red "$progress Second dump of $db.$tb returned non-zero exit code!" | errorlogit 2
				echo "${status[@]}"
				tail -n3 $dir/log/dbsync.log
				echo "$db.$tb" >> $dir/dbdump_fails.txt
			else
				ec green "$progress Second dump of $db.$tb was ok!"
			fi
		fi
		if [ "${status[0]}" = "0" ] && [ ! "${status[$((${#status[@]} - 1))]}" = "0" ]; then
			# dump succeeded but import failed, mark as failed
			ec red "$progress Dump of $db.$tb completed but import returned non-zero exit code!" | errorlogit 2
			echo "${status[@]}"
			tail -n3 $dir/log/dbsync.log
			echo "$db.$tb" >> $dir/dbdump_fails.txt
		fi
		let n+=1
	done
	ec green "$progress $db complete!"
}
