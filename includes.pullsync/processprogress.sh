rocessprogress() { #shared portion of the final/sync progress functions, pass cpanel user as $1. fills 5 rows of terminal space per process.
	local user ind0 homedirfile ind1 ind2 mailcount prog2 dblist dbcount currentdb position prog3
	user=$1
	# tail the end of the log for that user if it exists
	if [ -s "$dir/log/$user.error.log" ]; then
		grep -q ERROR "$dir/log/$user.error.log" 2> /dev/null && ind0="$xx " || ind0="$wn "
	fi
	echo -e "$ind0$(tail -1 "$dir/log/$user.loop.log" 2> /dev/null)$c"
	if grep -q "Syncing files" "$dir/log/$user.loop.log" 2> /dev/null; then #always print these lines once we get to or past the homedir sync section of rsync_homedir()

		# homedir
		homedirfile=$(grep "/$user/" <<< "$_lsof" | grep -v "/$user/mail/" | sed 's/^n//' | tail -1)
		#TODO will show a checkmark even if rsync still running, but no file moving
		[ ! "$homedirfile" ] && ind1=$cm || ind1=$hg
		#TODO add prog1 with df?
		ecnl white "Home: $ind1 $(rev <<< "$homedirfile" | cut -d. -f2- | cut -c1-$(($(tput cols) - 10)) | rev)$c"

		# mail
		grep "bash -c rsync_email ${user} " <<< "$_ps" | grep -qv "grep" && ind2=$hg || ind2=$cm
		mailcount=$(grep -c "^$user " "$dir/mapping.email.tsv")
		if [ "$mailcount" -gt 0 ]; then
			# get position from the completed mail users in $user.mail.log since they are run in parallel and could finish at different times
			maildone=$(wc -l < "$dir/log/$user.mail.log" 2> /dev/null || echo 0)
			# shellcheck disable=SC2017
			prog2="$maildone/$mailcount ($(((${maildone:-0}*100/${mailcount:-1}*100)/100))%)"
		else
			prog2="0/0 (100%)"
		fi
		ecnl white "Mail: $ind2 $prog2 $(awk -F/ '/\/'"$user"'\/mail\// {if ($5=="new") {print $6 "@" $5} else {print $5}}' <<< "$_lsof" | sort -u | paste -sd' ' | cut -c1-$(($(tput cols) - 25)))$c"

		# db
		dblist=$(awk '/^'"$user"' / {print $2}' "$dir/mapping.db.tsv")
		dbcount=$(wc -l <<< "$dblist")
		if [ "$dbcount" -gt 0 ]; then
			if grep -e "bash -c mysql_dbsync_user $user " <<< "$_ps" | grep -qv "grep"; then
				currentdb=$(echo "$_ps" | grep -E "parallel_mysql_dbsync ($(echo "$dblist" | tr ' ' '|'))" | grep -vE "(grep|parallel )" | awk '{print $(NF-1)}' | tail -1)
				# get position from the dblist since databases are run in order and not in parallel
				position=$(awk '/^'"$currentdb"'$/{print (NR-1)}' <<< "$dblist" | tail -1)
				# shellcheck disable=SC2017
				prog3="$position/$dbcount ($(((${position:-0}*100/${dbcount:-1}*100)/100))%)"
				ecnl white "DBs:  $hg $prog3 $currentdb: $(grep "parallel_mysql_dbsync $currentdb" <<< "$_ps" | grep -vE "(grep|parallel )" | awk '{print $NF}' | sort -u | paste -sd' ' | cut -c1-$(($(tput cols) - 40)))$c"
			else
				ecnl white "DBs:  $cm $dbcount/$dbcount (100%) $c"
			fi
		else
			ecnl white "DBs:  $cm 0/0 (100%)$c"
		fi
	else
		echo -e "$c\n$c\n$c"
	fi
	echo -e "---$c"
}
