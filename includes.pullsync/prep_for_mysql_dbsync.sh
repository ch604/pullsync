prep_for_mysql_dbsync() { #get ready for a sync by setting variables and backing up a few things
	local mysqldumpver
	# this avoids mysql.proc problems during import
	ec yellow "Running a local mysql_upgrade to ensure metadata in mysql.proc is correct..."
	sql upgrade --force --upgrade-system-tables &> /dev/null

	# test source mysqldump version over/under 5.0.42 and set options appropriately
	mysqldumpver=$(sssh_sql dump --version | tr ' ' '\n' | grep "[0-9\.]*-" | tr -d ',')
	if [ "$mysqldumpver" != "$(echo -e "$mysqldumpver\n5.0.42" | sort -V | head -1)" ]; then
		mysqldumpopts="--opt --force --log-error=$remote_tempdir/dbdump.log --max_allowed_packet=1000000000"
	else
		mysqldumpopts="--opt -Q"
	fi

	ec yellow "Backing up local grants..."
	# shellcheck disable=SC2174
	mkdir -p -m600 "$dir/pre_dbdumps"
	( (sql -BN -e "SELECT DISTINCT CONCAT('SHOW GRANTS FOR ''', user, '''@''', host, ''';') AS query FROM mysql.user" | parallel -j3 sql -re 2> /dev/null | sed 's/\(GRANT .*\)/\1;/;s/^\(Grants for .*\)/## \1 ##/;/##/{x;p;x;}' > "$dir/pre_dbdumps/mysql.grants.local.sql") & )

	#set a few variables
	ec yellow "Setting a few mysql variables..."
	sssh_sql -e 'set global net_write_timeout=600; set global net_read_timeout=300' 2>&1 | stderrlogit 3
	[ "$(sql -Nse 'select @@max_allowed_packet' 2> /dev/null)" -lt 999999488 ] && sql -e 'set global max_allowed_packet=1000000000' 2>&1 | stderrlogit 3
	[ "$(sql -Nse 'select @@bulk_insert_buffer_size' 2> /dev/null)" -lt 256000000 ] && sql -e 'set global bulk_insert_buffer_size=256000000' 2>&1 | stderrlogit 3
	[ "$(sql -Nse 'select @@innodb_buffer_pool_size' 2> /dev/null)" -lt 1073741824 ] && sql -e 'set global innodb_buffer_pool_size=1024000000' 2>&1 | stderrlogit 3
	[ "$(sql -Nse 'select @@innodb_write_io_threads' 2> /dev/null)" -lt 16 ] && sql -e 'set global innodb_write_io_threads=16' 2>&1 | stderrlogit 3
	[ "$(sql -Nse 'select @@innodb_flush_log_at_trx_commit' 2> /dev/null)" -ne 2 ] && sql -e 'set global innodb_flush_log_at_trx_commit=2' 2>&1 | stderrlogit 3

	#get a list of databases that have stored routines for later
	sssh_sql -BNe 'select db from mysql.proc where db<>"sys" and db<>"mysql"' 2> /dev/null | sort -u > "$dir/pre_dbdumps/routineslist.txt"
}
