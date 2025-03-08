unowneddbs() { #check for dbs that are not owned by any cpanel user
	local remotedbs remoteowneddbs _dbfile
	# get a list of all dbs
	remotedbs=$(sssh_sql -Bse 'show databases;' | grep -Ev -e "^(${baddbs})$" -e "^logaholicDB" -e "^cptmpdb")
	if [ -f "$dir/var/cpanel/databases/dbindex.db.json" ]; then
		# list out owned databases
		remoteowneddbs=$(jq -r '.MYSQL | keys[]' "$dir/var/cpanel/databases/dbindex.db.json")
		while read -r db; do
			# while listing remotedbs, if the database is not in the list of owned dbs, add it to the unowned db list
			grep -q -x "$db" <<< "$remoteowneddbs" || ( ec lightRed "$db doesn't exist in remote cPanel but does in MySQL" && echo "$db" >> "$dir/unowneddbs.txt" )
		done <<< "$remotedbs"
	else
		ec red "Remote dbindex.db.json not found, assuming all databases are NOT in cpanel..." | errorlogit 3 root
		ec lightRed "$remotedbs"
		echo "$remotedbs" >> "$dir/unowneddbs.txt"
	fi

	# if there are any unowned databases, print out
	if [ -s "$dir/unowneddbs.txt" ] && [ ! "$autopilot" ]; then
		ec yellow "Found unowned databases! (logged to $dir/unowneddbs.txt)" | errorlogit 3 root
		# continue if these dbs are already in the include file, otherwise prompt tech to add/sync them
		if [ -s /root/db_include.txt ] && ! diff -q <(sort "$dir/unowneddbs.txt" 2> /dev/null) <(sort /root/db_include.txt 2> /dev/null) &> /dev/null; then #files are the same (!diff)
			ec green "Unowned db list and db_include.txt already match."
		else
			# warn if there are already dbs in list
			if [ -s /root/db_include.txt ]; then
				ec lightRed "Careful! /root/db_include.txt already has $(wc -l < /root/db_include.txt) lines in it!"
			else
				ec yellow "/root/db_include.txt appears to be empty currently."
			fi
			if yesNo "Combine ALL of these detected databases to /root/db_include.txt to be synced during final, update, and mysql-only syncs?"; then
				# tech wants to sync these databases
				ec yellow "Combining..."
				_dbfile=$(mktemp)
				cat "$dir/unowneddbs.txt" /root/db_include.txt 2> /dev/null | grep -v "^$" | sort -u > "$_dbfile"
				mv "$_dbfile" /root/db_include.txt
				echo "Combined all unowned dbs (cat $dir/unowneddbs.txt) to /root/db_include.txt" | errorlogit 4 root
			else
				ec yellow "OK, don't forget you can add databases to /root/db_include.txt on your own to be synced during final/update/mysql syncs!"
			fi
		fi
	elif [ -s "$dir/unowneddbs.txt" ] && [ "$autopilot" ]; then
		# we are on autopilot, dont do anything
		ec yellow "Found unowned databases! (cat $dir/unowneddbs.txt)" | errorlogit 3 root
		ec red "I'm on autopilot, so I'm not appending anything! Deal with these databases manually later!" | errorlogit 2 root
	else
		ec green "No unowned databases found."
	fi

	if [ -s /root/db_include.txt ]; then
		if echo -e "final\nprefinal\nmysql\nupdate" | grep -qx "$synctype"; then
			# on final syncs, always sync these included dbs
			ec yellow "The contents of /root/db_include.txt will be synced during this final/update/mysql session (as well as cPanel-owned dbs)."
			say_ok
		else #initial synctype
			ec yellow "/root/db_include.txt reads:"
			logit < /root/db_include.txt
			if yesNo "Sync the databases in this file during this non-final/update/mysql session?"; then
				syncunowneddbs=1
			fi
		fi
	fi
}
