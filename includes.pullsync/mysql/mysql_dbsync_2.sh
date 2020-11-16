mysql_dbsync_2(){ # syncs the databases for the user passed as $1. if the db doesnt exist, creates it and attempts to add grants. progress as #/# is passed as $2.
	# get the passed variable
	local user=$1
	local progress="$2 | $user:"
	# ensure mysql is running on source forever
	while ! ssh ${sshargs} -n ${ip} "mysqladmin status > /dev/null" ; do # check if mysql is running using a more universal method
		ec lightRed "$progress Mysql does not seem to be running on remote server per 'mysqladmin status'! Attempting automatic restart..."
		ssh ${sshargs} -n ${ip} "[ -f /etc/init.d/mysql ] && /etc/init.d/mysql restart || service mysql restart"
		ec lightRed "$progress Sleeping for 10 before retry. If you see this a second time, please restart mysql on the source server manually..."
		sleep 10
		ssh ${sshargs} -n ${ip} "mysql -e 'set global net_write_timeout=600'; mysql -e 'set global net_read_timeout=300'" 2>&1 | stderrlogit 3
	done

	# make the list of dbs for this user
	local dblist=$(user_mysql_listgen $user)
	[ -f /root/db_exclude.txt ] && dblist=$(echo "$dblist" | grep -vx -f /root/db_exclude.txt)
	local db_count=$(echo "$dblist" | wc -l)
	local p=1

	for db in $dblist; do
		local dbprog="$p/$db_count"
		# create db if it does not exist, and copy its grants
		if [ ! "$(mysql -e 'show databases;' |egrep -x "${db}")" ]; then
			ec red "$progress Mysql db $db ($dbprog) does not exist on this server! Creating and mapping..."
			echo "$db" >> $dir/missing_dbs.txt
			mysqladmin create "$db"
			/usr/local/cpanel/bin/dbmaptool $user --type mysql --dbs "$db"
			ec red "$progress Collecting grants..."
			local mysqluser=$(egrep \`$(echo "$db" | sed -e 's/_/\\\\_/')\` $dir/pre_dbdumps/mysql.grants.remote.sql | grep -v \'$user\' | cut -d\' -f2 | uniq | head -1)
			if [ "$mysqluser" ]; then
				grep \'$mysqluser\'@\'localhost\' $dir/pre_dbdumps/mysql.grants.remote.sql | grep -v \'root\' | tee -a $dir/missing_dbgrants.txt | mysql
				/usr/local/cpanel/bin/dbmaptool $user --type mysql --dbusers "$mysqluser"
			else
				ec lightRed "$progress Couldn't collect grant for $db ($dbprog)!" | tee -a $dir/missing_dbgrants.txt
			fi
		else
			# if the db does exist, back it up and zip it
			ec blue "$progress Backing up $db ($dbprog) to $dir/pre_dbdumps..."
			mysqldump --opt --routines "$db" | gzip > "$dir/pre_dbdumps/$db.sql.gz"
			chmod 600 "$dir/pre_dbdumps/$db.sql.gz"
		fi

		# dump routines first
		local DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump -ntdR \"$db\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
		declare -a status=( ${DUMP##*:} )
		if [ ! "${status[0]}" = "0" ]; then
			# dump failed, retry
			DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump -ntdR \"$db\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
			declare -a status=( ${DUMP##*:} )
			if [ ! "${status[0]}" = "0" ]; then
				# second dump failed too, mark as failed
				ec lightRed "$progress routines for $db ($dbprog) returned non-zero exit code. Might be corrupt."
				echo "${status[@]}"
				tail -n3 $dir/log/dbsync.log
				echo "$db ROUTINES" >> $dir/dbdump_fails.txt
				echo "[ERROR] $db ROUTINES failed to dump properly!" >> $dir/error.log
			fi
		fi

		# enumerate tables
		local tables=$(sssh "mysql \"$db\" -Bse 'show tables'")
		local table_count=$(echo "$tables" | wc -l)
		local n=1

		# perform the data sync if there are any tables
		[ "$tables" ] && echo "$tables" | while read tb; do
			local tableprog="$n/$table_count"
			ec purple "$progress Streaming dump of $db.$tb ($dbprog, $tableprog) to target..."
			# perform the dump in a subshell to collect the pipestatus, getting exit code for the dump and the import at the same time
			local DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump $mysqldumpopts \"$db\" \"$tb\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
			# turn the pipestatus into a usable array
			declare -a status=( ${DUMP##*:} )

			# parse the status to see if anything failed
			if [ ! "${status[0]}" = "0" ]; then
				# dump failed, retry
				ec red "$progress Dump of $db.$tb ($dbprog, $tableprog) returned non-zero exit code!"
				echo "${status[@]}"
				tail -n3 $dir/log/dbsync.log
				ec red "$progress Retrying dump of $db.$tb ($dbprog, $tableprog)..."
				DUMP=$( ssh ${sshargs} -n -C ${ip} "mysqldump $mysqldumpopts \"$db\" \"$tb\"" 2>> $dir/log/dbsync.log | mysql "$db" 2>> $dir/log/dbsync.log; printf :%s "${PIPESTATUS[*]}" )
				declare -a status=( ${DUMP##*:} )
				if [ ! "${status[0]}" = "0" ]; then
					# second dump failed too, mark as failed
					ec red "$progress Second dump of $db.$tb ($dbprog, $tableprog) returned non-zero exit code!"
					echo "${status[@]}"
					tail -n3 $dir/log/dbsync.log
					echo "$db.$tb" >> $dir/dbdump_fails.txt
					echo "[ERROR] $db.$tb failed to dump properly!" >> $dir/error.log
				else
					ec green "$progress Second dump of $db.$tb ($dbprog, $tableprog) was ok!"
				fi
			fi
			if [ "${status[0]}" = "0" ] && [ ! "${status[$((${#status[@]} - 1))]}" = "0" ]; then
				# dump succeeded but import failed, mark as failed
				ec red "$progress Dump of $db.$tb ($dbprog, $tableprog) completed but import returned non-zero exit code!"
				echo "${status[@]}"
				tail -n3 $dir/log/dbsync.log
				echo "$db.$tb" >> $dir/dbdump_fails.txt
				echo "[ERROR] $db.$tb failed to dump properly!" >> $dir/error.log
			fi
			let n+=1
		done
		let p+=1
	done
	ec green "$progress All databases complete!"
}
