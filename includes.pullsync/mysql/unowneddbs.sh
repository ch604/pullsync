unowneddbs() { #check for dbs that are not owned by any cpanel user
	# get a list of all dbs
	remotedbs=$(sssh "mysql -Bse 'show databases;'" | egrep -v -e "^(${baddbs})$" -e "^logaholicDB" -e "^cptmpdb")
	if [ -f $dir/var/cpanel/databases/dbindex.db.json ]; then
		# list out owned databases
		remoteowneddbs=$(egrep -o "\"[^\"]+\":\"[^\"]+\"" $dir/var/cpanel/databases/dbindex.db.json | sed -rn "s>^\"([^\"]+)\":\"([^\"]+)\".*>\1>p")
		while read db; do
			# while listing remotedbs, if the database is not in the list of owned dbs, add it to the unowned db list
			grep -q -x "${db}" <<< "$remoteowneddbs" || ( ec lightRed "$db doesn't exist in remote cPanel but does in MySQL" && echo "$db" >> $dir/unowneddbs.txt )
		done <<< "$remotedbs"
	else
		ec red "Remote dbindex.db.json not found, assuming all databases are NOT in cpanel..." | errorlogit 3
		ec lightRed "$remotedbs"
		echo "$remotedbs" >> $dir/unowneddbs.txt
	fi

	# if there are any unowned databases, print out
	if [ -s $dir/unowneddbs.txt ] && [ ! "$autopilot" ]; then
		ec yellow "Found unowned databases! (logged to $dir/unowneddbs.txt)" | errorlogit 3
		# continue if these dbs are already in the include file, otherwise prompt tech to add/sync them
		if [ $(diff -q <(sort $dir/unowneddbs.txt) <(sort /root/db_include.txt) &> /dev/null; echo $?) -eq 1 ]; then #files are different in either direction
			# warn if there are already dbs in list
			[ -s /root/db_include.txt ] && ec lightRed "Careful! /root/db_include.txt already has $(cat /root/db_include.txt | wc -l) lines in it!" || ec yellow "/root/db_include.txt appears to be empty currently."
			if yesNo "Combine ALL of these detected databases to /root/db_include.txt to be synced during final, update, and mysql-only syncs?"; then
				# tech wants to sync these databases
				ec yellow "Combining..."
				local _dbfile=$(mktemp)
				sort -u $dir/unowneddbs.txt /root/db_include.txt > $_dbfile
				mv $_dbfile /root/db_include.txt
				echo "Combined all unowned dbs (cat $dir/unowneddbs.txt) to /root/db_include.txt" | errorlogit 4
			else
				ec yellow "OK, don't forget you can add databases to /root/db_include.txt on your own to be synced during final/update/mysql syncs!"
			fi
		else
			ec green "Unowned db list and db_include.txt already match."
		fi
	elif [ -s $dir/unowneddbs.txt ] && [ "$autopilot" ]; then
		# we are on autopilot, dont do anything
		ec yellow "Found unowned databases! (cat $dir/unowneddbs.txt)" | errorlogit 3
		ec red "I'm on autopilot, so I'm not appending anything! Deal with these databases manually later!" | errorlogit 2
	else
		ec green "No unowned databases found."
	fi

	if [ -s /root/db_include.txt ]; then
		if [ "$synctype" = "final" ] || [ "$synctype" = "mysql" ] || [ "$synctype" == "update" ]; then
			# on final syncs, always sync these included dbs
			ec yellow "The contents of /root/db_include.txt will be synced during this final/update/mysql session (as well as cPanel-owned dbs)."
			say_ok
		else #initial synctype
			ec yellow "/root/db_include.txt reads:"
			cat /root/db_include.txt | logit
			if yesNo "Sync the databases in this file during this non-final/update/mysql session?"; then
				syncunowneddbs=1
			fi
		fi
	fi
}
