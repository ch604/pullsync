pgsql_dbsync() { # enumerates and syncs postgres databases
	if sssh "pgrep postgres &> /dev/null" || sssh "pgrep postmaster &> /dev/null"; then
		# pg on remote server
		ec yellow "Postgres found running on remote server..."
		if pgrep postgres &> /dev/null; then
			# pg on local server, time to sync
			ec yellow "Postgres running on local server, syncing dbs"
			for user in $userlist; do
				# run to locate db list for final sync.
				ec blue "Checking for postgres databases for $user..."
				if [[ -f "$dir/var/cpanel/databases/$user.json" ]]; then
					pgdbs=`cat $dir/var/cpanel/databases/$user.json | python -c 'import sys,json; dbs=json.load(sys.stdin)["PGSQL"]["dbs"].keys() ; print "\n".join(dbs)'`
				elif [ -f "$dir/var/cpanel/databases/$user.yaml" ]; then
					pgdbs=`cat $dir/var/cpanel/databases/$user.yaml | python -c 'import sys,yaml; dbs=yaml.load(sys.stdin, Loader=yaml.FullLoader)["PGSQL"]["dbs"].keys() ; print "\n".join(dbs)'`
				fi
				pgdbcount=`echo $pgdbs |wc -w`
				if [[ $pgdbcount -gt 0 ]]; then
					mkdir -p -m600 $dir/pgdumps
					mkdir -p -m600 $dir/pre_pgdumps/
					# dbs were found for this user! sync them
					for db in $pgdbs; do
						if ! psql -U postgres -t -A -c 'select datname from pg_database' | grep -q ^${db}$; then
							#database does not exist on target yet
							ec lightRed "Database does not exist on target, creating..."
							echo "$db (pgsql) GRANTS ARE MISSING" >> $dir/missing_dbs.txt
							psql -U postgres --quiet -c "create database ${db}"
							/usr/local/cpanel/bin/dbmaptool --type pgsql --user $user --db $db
						fi
						ec lightBlue "Copying and importing pgsql db $db..."
						# back up the local db
						pg_dump -Fc -c -U postgres $db > $dir/pre_pgdumps/$db.psql
						# stream the remote db
						sssh "pg_dump -Fc -c -U postgres $db" | pg_restore -Fc -U postgres -d $db
					done
				else
					ec green "No Postgres dbs found for $user."
				fi
			done
		else
			ec red "Postgres not found on local sever!"
		fi
	else
		ec green "Postgres not found on remote server."
	fi
}
