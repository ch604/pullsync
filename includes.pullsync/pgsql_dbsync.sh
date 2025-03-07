pgsql_dbsync() { # syncs postgres database passed as $1 for optional cpanel user $2
	local db user
	db=$1
	user=$2
	if ! psql -U postgres -tAc 'select datname from pg_database' | grep -q "^$db$"; then
		#database does not exist on target yet
		ec lightRed "Postgres database $db does not exist on target, creating..."
		echo "$db (pgsql) GRANTS ARE MISSING" >> "$dir/missing_dbs.txt"
		psql -U postgres --quiet -c "create database $db"
		[ "$user" ] && /usr/local/cpanel/bin/dbmaptool --type pgsql --user "$user" --db "$db"
	fi
	if [ ! "$skipsqlzip" ]; then
		# back up the local db
		pg_dump -Fc --clean -U postgres "$db" | gzip > "$dir/pre_pgdumps/$db.psql.gz"
		chmod 600 "$dir/pre_pgdumps/$db.psql.gz"
	fi
	# stream the remote db
	sssh "pg_dump -Fc --clean -U postgres $db" | pg_restore -Fc -U postgres -d "$db"
}
