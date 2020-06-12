prep_for_mysql_dbsync(){ #get ready for a sync by setting variables and backing up a few things
	ec yellow "Running a local mysql_upgrade to ensure metadata in mysql.proc is correct..."
	# this avoids mysql.proc problems during import
	mysql_upgrade --force --upgrade-system-tables &> /dev/null
	ec yellow "Backing up local grants..."
	mkdir -p -m600 $dir/pre_dbdumps
	# determine mysqldump version
	local mysqldumpver=`sssh 'mysqldump --version |cut -d" " -f6 |cut -d, -f1'`
	# test source version over/under 5.0.42 and set options appropriately
	[ $mysqldumpver != $(echo -e "$mysqldumpver\n5.0.42" | sort -V | head -1) ] && mysqldumpopts="--opt --routines --force --log-error=$remote_tempdir/dbdump.log --max_allowed_packet=1000000000" || mysqldumpopts="--opt -Q"
	#back up grants
	mysql -B -N -e "SELECT DISTINCT CONCAT('SHOW GRANTS FOR ''', user, '''@''', host, ''';') AS query FROM mysql.user" | while read i; do mysql -e "$i"; done | sed 's/\(GRANT .*\)/\1;/;s/^\(Grants for .*\)/## \1 ##/;/##/{x;p;x;}' | sed 's/\\\\/\\/g' > $dir/pre_dbdumps/mysql.grants.local.sql
	sssh "mysql -BN -e \"SELECT DISTINCT CONCAT('SHOW GRANTS FOR ''', user, '''@''', host, ''';') AS query FROM mysql.user\" | while read i; do mysql -e \"\$i\"; done" | sed 's/\(GRANT .*\)/\1;/;s/^\(Grants for .*\)/## \1 ##/;/##/{x;p;x;}' | sed 's/\\\\/\\/g' > $dir/pre_dbdumps/mysql.grants.remote.sql
	#set a few variables
	sssh "mysql -e 'set global net_write_timeout=600'; mysql -e 'set global net_read_timeout=300'" 2>&1 | stderrlogit 3
	mysql -e 'set global max_allowed_packet=1000000000' 2>&1 | stderrlogit 3
	mysql -e 'set global bulk_insert_buffer_size=256000000' 2>&1 | stderrlogit 3
}
