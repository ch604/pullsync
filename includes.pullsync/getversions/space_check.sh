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
			for remotequota in $(cat $dir/repquota.a.txt | grep ^${user}\  | awk '{print $3}'); do
				remote_used_space=$(( $remote_used_space + $remotequota ))
			done
		done
	else
		# no repquota, just count the df line for /home
		remote_used_space=`cat $dir/df.txt | awk '{print $3}'`
	fi

	# store more info about free space and about target
	remote_free_space=`cat $dir/df.txt | awk '{print $4}'`
	local_free_space=`df -P /home | tail -n1 | awk '{print $4}'`
	remote_mysql_datadir=`sssh "mysql -BNe 'show variables like \"datadir\"'" | awk '{print $2}'`
	remote_mysql_usage=`sssh "du -s $remote_mysql_datadir --exclude=eximstats" | awk '{print $1}'`

	# homedir disk usage, run on initial synctypes
	if [[ "$synctype" == "single" || "$synctype" == "list" || "$synctype" == "domainlist" || "$synctype" == "all" || "$synctype" = "versionmatching" ]]; then
		ec white "Remote used space: $(echo "scale=1; $remote_used_space / 1024 / 1024" | bc) Gb "
		ec white "Local free space : $(echo "scale=1; $local_free_space / 1024 / 1024" | bc) Gb "
		[ $iusedrepquota ] && ec lightGreen 'I used the more accurate repquota method to determine this (scoped to userlist plus mysql)' || ec lightGreen 'I used the less accurate df -P method to determine this (the size of the /home partition)'
		if [[ $remote_used_space -gt $local_free_space ]] ; then
			# throw error if there is insuficcient disk space on target
			ec lightRed 'There does not appear to be enough free space on this server when comparing the home partitions!'
			[ $iusedrepquota ] && ec lightRed 'WARNING! I USED THE MORE ACCURATE REPQUOTA METHOD TO DETERMINE THIS!'
			if [ "$synctype" = "versionmatching" ]; then
				# downgrade the error if its versionmatching type
				ec yellow "synctype is versionmatching, not a real error."
			else
				ec lightCyan "Press enter to override and continue anyway."
				[ ! "$autopilot" ] && rd || exitcleanup 9
			fi
		fi
	fi

	# mysql disk usage, run on all synctypes
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
