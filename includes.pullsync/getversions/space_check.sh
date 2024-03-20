space_check() { #check disk usage on local and remote servers, and make sure there is enough space to store data on both
	ec yellow "Comparing disk usage..."
	# output df from source so it can be parsed
	sssh "df -P /home/ | tail -1" > $dir/df.txt
	if [ "$userlist" ] && sssh "[ -f $(cat $dir/df.txt | awk '{print $6}')quota.user -o -f $(cat $dir/df.txt | awk '{print $6}')aquota.user ]" && [ `sssh "which repquota 2> /dev/null"` ]; then
		# not versionmatching (userlist set) and can use repquota, store more accurate info
		iusedrepquota=1
		remote_used_space=0
		sssh "repquota -a" > $dir/repquota.a.txt
		for user in $userlist mysql; do
			for remotequota in $(awk '/^'${user}' / {print $3}' $dir/repquota.a.txt); do
				remote_used_space=$(( $remote_used_space + $remotequota ))
			done
		done
		if [[ "$synctype" == "prefinal" || "$synctype" == "final" || "$synctype" == "update" || "$synctype" == "homedir" ]]; then
			if [ -f $(df -P /home/ | tail -1 | awk '{print $6}')aquota.user -o -f $(df -P /home/ | tail -1 | awk '{print $6}')quota.user ]; then
				#final/update sync check target acct usage
				iusedlocalrepquota=1
				local_used_space=0
				repquota -a > $dir/repquota.a.local.txt
				for user in $userlist mysql; do
					for localquota in $(awk '/^'${user}'\ / {print $3}' $dir/repquota.a.local.txt); do
						local_used_space=$(( $local_used_space + $localquota ))
					done
				done
				finaldiff=$(( $remote_used_space - $local_used_space ))
				[ $finaldiff -gt 0 ] || finaldiff=0
			else
				finaldiff=0
			fi
		fi
	else
		# no repquota, just count the df line for /home
		remote_used_space=`cat $dir/df.txt | awk '{print $3}'`
		finaldiff=0
	fi

	# store more info about free space and about target
	remote_free_space=`cat $dir/df.txt | awk '{print $4}'`
	if [ $(echo $localhomedir | wc -w) = 1 ]; then
		local_free_space=$(df -P /home | tail -n1 | awk '{print $4}')
	else
		local dirstocheck=$(for each in /home $localhomedir; do df -P $each | tail -n1 | awk '{print $1}'; done | sort -u)
		local_free_space=0
		for each in $dirstocheck; do
			local_free_space=$(( $local_free_space + $(df $each | tail -n1 | awk '{print $4}') ))
		done
	fi
	remote_mysql_datadir=`sssh "mysql -BNe 'show variables like \"datadir\"'" | awk '{print $2}'`
	remote_mysql_usage=`sssh "du -s $remote_mysql_datadir --exclude=eximstats" | awk '{print $1}'`

	# homedir disk usage, run on initial synctypes
	if [[ "$synctype" == "single" || "$synctype" == "list" || "$synctype" == "domainlist" || "$synctype" == "all" || "$synctype" = "versionmatching" ]]; then
		ec white "Remote used space: $(echo "scale=1; $remote_used_space / 1024 / 1024" | bc) Gb "
		ec white "Local free space : $(echo "scale=1; $local_free_space / 1024 / 1024" | bc) Gb "
		[ $iusedrepquota ] && ec lightGreen 'I used the more accurate repquota method to determine this (scoped to userlist plus mysql)' || ec lightGreen 'I used the less accurate df -P method to determine this (the size of the /home partition)'
		if [[ $remote_used_space -gt $local_free_space ]]; then
			# throw error if there is insuficcient disk space on target
			ec lightRed 'There does not appear to be enough free space on this server when comparing all available target home partitions: '$(echo $localhomedir | tr '\n' ' ')
			[ $iusedrepquota ] && ec lightRed 'WARNING! I USED THE MORE ACCURATE REPQUOTA METHOD TO DETERMINE THIS!'
			if [ "$synctype" = "versionmatching" ]; then
				# downgrade the error if its versionmatching type
				ec yellow "synctype is versionmatching, not a real error."
			else
				ec lightCyan "Press enter to override and continue anyway."
				[ ! "$autopilot" ] && rd || exitcleanup 9
			fi
		fi
	elif [[ "$synctype" == "prefinal" || "$synctype" == "final" || "$synctype" == "update" || "$synctype" == "homedir" ]]; then
		#if repquota was used, compare needed target space
		ec white "Remote used space: $(echo "scale=1; $remote_used_space / 1024 / 1024" | bc) Gb "
		ec white "Local free space : $(echo "scale=1; $local_free_space / 1024 / 1024" | bc) Gb "
		if [ $iusedlocalrepquota ]; then
			ec white "Expected sync amount for final/update: $(echo "scale=1; $finaldiff / 1024 / 1024" | bc) Gb"
		else
			ec white "Couldn't calculate local repquota for final/update sync amount."
		fi
		if [[ $finaldiff -gt $local_free_space ]]; then
			# throw error if there is insuficcient disk space on target
			ec lightRed 'There does not appear to be enough free space on this server when comparing all available target home partitions: '$(echo $localhomedir | tr '\n' ' ')
			ec lightRed 'WARNING! I USED THE MORE ACCURATE REPQUOTA METHOD TO DETERMINE THIS!'
			ec lightCyan "Press enter to override and continue anyway."
			[ ! "$autopilot" ] && rd || exitcleanup 9
		fi
	fi

	# mysql disk usage, run on all synctypes to make sure theres space on source for skeleton backups. TODO this does not account for skipdb cpanel backups or mailman usage.
	if [[ $(( $remote_mysql_usage + 1024000 )) -gt $remote_free_space ]]; then
		# add a gig to remote usage to be safe
		ec white "Estimated temp usage: $(echo "scale=1; ($remote_mysql_usage + 1024000) / 1024 / 1024" | bc) Gb "
		ec white "Remote free space   : $(echo "scale=1; $remote_free_space / 1024 / 1024" | bc) Gb "
		ec lightRed 'There does not appear to be enough free space on the source server to store temporary files!'
		if [ "$synctype" = "versionmatching" ]; then
			ec yellow "synctype is versionmatching, not a real error."
		else
			ec lightCyan "Press enter to override and continue anyway."
			[ ! "$autopilot" ] && rd || exitcleanup 9
		fi
	fi
}
