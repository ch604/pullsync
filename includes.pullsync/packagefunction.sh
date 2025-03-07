packagefunction() { #$1 is position, $2 is username. this is where the actual packaging, copying, and restoring happens. programmed with global variables and argument import so it can be looped in parallel.
	local user restorepkg_args pkgacct_args old_user_ip progress cpmovefile userhome oldbasedir newbasedir
	user=$2
	restorepkg_args="--allow_reseller"
	pkgacct_args="--skiphomedir --skipbwdata --skiplogs"
	[ "$dbbackup_schema" ] && pkgacct_args="$pkgacct_args --dbbackup=schema"
	old_user_ip=$(awk -F= '/^IP=/ {print $2}' $dir/var/cpanel/users/$user)
	[ "$remainingcount" ] && progress="$(($1 + $(cat $dir/realresellers.txt | wc -w) ))/$user_total | $user:" || progress="$1/$user_total | $user:"
	# package the remote account and locate it on the remote server
	ec lightBlue "$progress Packaging $user..." | tee -a $dir/log/pkgacct.$user.log
	sssh "/scripts/pkgacct $pkgacct_args $user $remote_tempdir" >> $dir/log/pkgacct.$user.log 2>&1
	cpmovefile=$(sssh "find $remote_tempdir/ -maxdepth 1 -name cpmove-$user.tar.gz -mtime -1" | head -n1)
	if [ "$cpmovefile" ]; then
		# if the package was created, bring it to the target
		ec lightPurple "$progress Rsyncing cpmove..."
		srsync $ip:$cpmovefile $dir/cpmovefiles/
		if ( [ "$old_user_ip" != "$old_main_ip" ] && [ "$ded_ip_check" ] && ! grep -l $old_user_ip $dir/var/cpanel/users/* | grep -qv "/$user$" ) || [ "$single_dedip" = "yes" ]; then
			restorepkg_args="$restorepkg_args --ip=y"
		fi
		sem --wait --id restore_pkg_running #wait if other restorepkg are running
		# begin restoration
		ec lightCyan "$progress Restoring..."
		sem --fg --id restore_pkg_running --jobs 1 -u /scripts/restorepkg $restorepkg_args $dir/cpmovefiles/cpmove-$user.tar.gz >> $dir/log/restorepkg.$user.log
		if [ -f /var/cpanel/users/$user ] && [ -f $dir/var/cpanel/users/$user ]; then
		 	#ensure userdata has correct path
			userhome=$(eval echo ~${user})
			if [ -h $userhome ]; then
				oldbasedir="$(dirname $userhome)/"
				newbasedir="$(dirname "$(readlink -f $userhome)")/"
				sed -i 's|'${oldbasedir}'|'${newbasedir}'|g' /var/cpanel/userdata/$user/* /etc/proftpd/$user 2> /dev/null
				sed -i 's|'${oldbasedir}${user}'|'${newbasedir}${user}'|g' /etc/passwd $userhome/etc/*/passwd 2> /dev/null
				/scripts/rebuildhttpdconf
			fi
			#write mapping file after restore
			echo "$user $(awk -F: '/^'$user':/ {print $6}' $dir/etc/passwd) $(eval echo ~${user})" >> $dir/mapping.homedir.tsv
			if [ "$synctype" != "skeletons" ]; then
				# skip the data copying tasks when not copying data, i.e. using the skeletons synctype
				[ "$dbbackup_schema" ] && sem --id datamove${user} -j 3 -u mysql_dbsync_user $user $progress >> $dir/log/$user.db.log
				sem --id datamove${user} -j 3 -u rsync_homedir $user $progress
				sem --id datamove${user} -j 3 -u rsync_email $user 0
				sem --wait --id datamove${user}
				eternallog $user
			fi
			# perform post-restore tasks
			if [ "$dopgsync" ]; then
				pglist=$(user_pgsql_listgen $user)
				if [ "$pglist" ]; then
					for db in $pglist; do
						ec blue "$progress | $user: Importing pgsql db $db..."
						pgsql_dbsync $db $user
					done
				fi
			fi
			install_ssl $user
			hosts_file $user
			apache_user_includes $user
			[ "$ipv6" ] && set_ipv6 $user
		else
			#restore failed
			ec red "Warning: Cpanel user $user not found!" | errorlogit 2 "$user"
			echo $user >> $dir/did_not_restore.txt
		fi
	else
		# if the package failed, mark as failed
		ec lightRed "Error: Did not find backup file for user $user!" | errorlogit 2 "$user"
		echo $user >> $dir/did_not_restore.txt
	fi
}
