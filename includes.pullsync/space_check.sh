space_check() { #check disk usage on local and remote servers, and make sure there is enough space to store data on both
	local homedf remotehomemounts dirs_to_check local_free_space remote_free_space local_used_space _rqa _lqra iusedlocalrepquota remote_mysql_datadir remote_mysql_usage
	ec yellow "Comparing disk usage..."
	# output df from source so it can be parsed
	homedf=$(sssh "df -P /home/" | tail -1)
	if [ "$userlist" ] && sssh "[[ -f $(awk '{print $6}' <<< "$homedf")/quota.user || -f $(awk '{print $6}' <<< "$homedf")/aquota.user ]]" && sssh "which repquota &> /dev/null"; then
		# not versionmatching (userlist set) and can use repquota, store more accurate info
		iusedrepquota=1
		remote_used_space=0
		_rqa=$(mktemp)
		sssh "repquota -a 2> /dev/null" > "$_rqa"
		for user in $userlist mysql; do
			while read -r remotequota; do
				((remote_used_space+=remotequota))
			done < <(awk '/^'"$user"' / {print $3}' "$_rqa")
		done
		rm -f "$_rqa"
		if echo -e "final\nupdate\nhomedir\nemail\nemaillist" | grep -qx "$synctype"; then
			if [[ -f $(df -P /home/ | awk 'END {print $6}')/aquota.user || -f $(df -P /home/ | awk 'END {print $6}')/quota.user ]]; then
				#final/update sync check target acct usage
				iusedlocalrepquota=1
				local_used_space=0
				_lrqa=$(mktemp)
				repquota -a 2> /dev/null > "$_lrqa"
				for user in $userlist mysql; do
					while read -r localquota; do
						((local_used_space+=localquota))
					done < <(awk '/^'"$user"' / {print $3}' "$_lrqa")
				done
				rm -f "$_lrqa"
				finaldiff=$((remote_used_space - local_used_space))
				[ "$finaldiff" -le 0 ] && finaldiff=0
			else
				finaldiff=0
			fi
		fi
	else
		# no repquota, just count the df line for all remote homedirs
		if [ "$(wc -w <<< "$remotehomedir")" -eq 1 ]; then
			remote_used_space=$(awk '{print $3}' <<< "$homedf")
		else
			remote_used_space=0
			remotehomemounts=$(for each in $remotehomedir; do sssh "findmnt -nT $each" | awk '{print $1}'; done | sort -u)
			for each in $remotehomemounts; do
				remote_used_space=$((remote_used_space + $(sssh "df $each" | awk 'END {print $3}')))
			done
		fi
		finaldiff=0
	fi

	# store more info about free space and about target
	remote_free_space=$(awk '{print $4}' <<< "$homedf")
	if [ "$(wc -w <<< "$localhomedir")" -eq 1 ]; then
		local_free_space=$(df -P /home | awk 'END {print $4}')
	else
		dirs_to_check=$(for each in /home $localhomedir; do df -P "$each" | awk 'END {print $1}'; done | sort -u)
		local_free_space=0
		for each in $dirs_to_check; do
			local_free_space=$((local_free_space + $(df "$each" | awk 'END {print $4}') ))
		done
	fi
	remote_mysql_datadir=$(sssh_sql -BNe 'show variables like "datadir"' | awk '{print $2}')
	remote_mysql_usage=$(sssh "du -s $remote_mysql_datadir --exclude=eximstats" | awk '{print $1}')

	# homedir disk usage, run on initial synctypes
	if echo -e "single\nlist\ndomainlist\nall\nversionmatching\nskeletons" | grep -qx "$synctype"; then
		ec white "Remote used space: $(echo "scale=1; $remote_used_space / 1024 / 1024" | bc) Gb "
		ec white "Local free space : $(echo "scale=1; $local_free_space / 1024 / 1024" | bc) Gb "
		if [ "$iusedrepquota" ]; then
			ec lightGreen "I used the more accurate repquota method to determine this (scoped to userlist plus mysql)"
		else
			ec lightGreen "I used the less accurate df -P method to determine this (the size of the /home partition)"
		fi
		if [[ "$remote_used_space" -gt "$local_free_space" ]]; then
			# throw error if there is insuficcient disk space on target
			ec lightRed "There does not appear to be enough free space on this server when comparing all available target home partitions: $(paste -sd' ' <<< "$localhomedir")"
			[ "$iusedrepquota" ] && ec lightRed "WARNING! I USED THE MORE ACCURATE REPQUOTA METHOD TO DETERMINE THIS!"
			if [ "$synctype" == "versionmatching" ]; then
				# downgrade the error if its versionmatching type
				ec yellow "synctype is versionmatching, not a real error."
			else
				ec lightCyan "Press enter to override and continue anyway."
				[ "$autopilot" ] && exitcleanup 9
				rd
			fi
		fi
	elif echo -e "final\nprefinal\nupdate\nhomedir\nemail\nemaillist" | grep -qx "$synctype"; then
		#if repquota was used, compare needed target space
		ec white "Remote used space: $(echo "scale=1; $remote_used_space / 1024 / 1024" | bc) Gb "
		ec white "Local free space : $(echo "scale=1; $local_free_space / 1024 / 1024" | bc) Gb "
		if [ "$iusedlocalrepquota" ]; then
			ec white "Expected sync amount for final/update: $(echo "scale=1; $finaldiff / 1024 / 1024" | bc) Gb"
		else
			ec white "Couldn't calculate local repquota for final/update sync amount."
		fi
		if [ "$finaldiff" -gt "$local_free_space" ]; then
			# throw error if there is insuficcient disk space on target
			ec lightRed "There does not appear to be enough free space on this server when comparing all available target home partitions: $(paste -sd' ' <<< "$localhomedir")"
			ec lightRed "WARNING! I USED THE MORE ACCURATE REPQUOTA METHOD TO DETERMINE THIS!"
			ec lightCyan "Press enter to override and continue anyway."
			[ "$autopilot" ] && exitcleanup 9
			rd
		fi
	fi

	# mysql disk usage, run on all synctypes to make sure theres space on source for skeleton backups. TODO this does not account for skipdb cpanel backups or mailman usage.
	if [ "$synctype" != "versionmatching" ] && [ "$((remote_mysql_usage + 1024000))" -gt "$remote_free_space" ]; then
		# add a gig to remote usage to be safe
		ec white "Estimated temp usage: $(echo "scale=1; ($remote_mysql_usage + 1024000) / 1024 / 1024" | bc) Gb "
		ec white "Remote free space   : $(echo "scale=1; $remote_free_space / 1024 / 1024" | bc) Gb "
		ec lightRed "There does not appear to be enough free space on the source server to store temporary files!"
		ec lightCyan "Press enter to override and continue anyway."
		[ "$autopilot" ] && exitcleanup 9
		rd
	fi
}
