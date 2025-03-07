mysql_listgen() { #generate list of databases to sync from userlist
	ec yellow "Generating database list..."
	dblist_restore="" #create the variable
	for user in $userlist; do
		# generate a list per user
		dblist=$(user_mysql_listgen "$user")
		if [ "$dblist" ]; then
			# if the variable has size, add it to the restore list
			ec cyan "DBs for $user:"
			echo "$dblist" | logit
			dblist_restore=$(echo -e "$dblist_restore\n$dblist")
		fi
	done
	# if there are dbs to include, add them to the list of dbs to restore
	[ -f /root/db_include.txt ] && dblist_restore=$(echo -e "$dblist_restore\n$(cat /root/db_include.txt)") && ec red "Included dbs from /root/db_include.txt. Bail if these dont look good:" && logit < /root/db_include.txt
	# clean up bad dbs
	sanitize_dblist
	say_ok
}
