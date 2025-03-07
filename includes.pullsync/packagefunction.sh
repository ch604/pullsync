packagefunction(){ #$1 is position, $2 is username. this is where the actual packaging, copying, and restoring happens. programmed with global variables and argument import so it can be looped in parallel.
	# set a few variables locally to not conflict with other running parallel processes
	local user=$2
	local restorepkg_args="--allow_reseller"
	local pkgacct_args="--skiphomedir"
	[ $dbbackup_schema ] && pkgacct_args="$pkgacct_args --dbbackup=schema"
	local old_user_ip=$(awk -F= '/^IP=/ {print $2}' $dir/var/cpanel/users/$user)
	[ "$remainingcount" ] && local progress="$(($1 + $(cat $dir/realresellers.txt | wc -w) ))/$user_total | $user:" || local progress="$1/$user_total | $user:"
	# package the remote account and locate it on the remote server
	ec lightBlue "$progress Packaging $user..." | tee -a $dir/log/pkgacct.$user.log
	sssh "/scripts/pkgacct $pkgacct_args $user $remote_tempdir" >> $dir/log/pkgacct.$user.log 2>&1
	local cpmovefile=$(sssh "find $remote_tempdir/ -maxdepth 1 -name cpmove-$user.tar.gz -mtime -1" | head -n1)
	if [ $cpmovefile ]; then
		# if the package was created, bring it to the target
		ec lightPurple "$progress Rsyncing cpmove..."
		rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:$cpmovefile $dir/cpmovefiles/
		if ([[ $old_user_ip != $old_main_ip ]] && [ "$ded_ip_check" = "1" ] && ! grep -l $old_user_ip $dir/var/cpanel/users/* | grep -qv /${user}$) || [ "$single_dedip" = "yes" ]; then
			restorepkg_args="$restorepkg_args --ip=y"
		fi
		sleep $(($1 % 3)) #keep the wait commands a bit apart
		sem --wait --id restore_pkg_running #wait if other restorepkg are running
		# begin restoration
		ec lightCyan "$progress Restoring..."
		sem --fg --id restore_pkg_running --jobs 1 -u /scripts/restorepkg $restorepkg_args $dir/cpmovefiles/cpmove-$user.tar.gz >> $dir/log/restorepkg.$user.log
		if [ -f /var/cpanel/users/$user ] && [ -f $dir/var/cpanel/users/$user ]; then
			if [ ! "$synctype" = "skeletons" ]; then
				# skip the data copying tasks when not copying data, i.e. using the skeletons synctype
				local shortprog=$(echo "$progress" | awk '{print $1}')
				if [ $dbbackup_schema ]; then
					# bring over dbs if they were skipped for pkgacct
					sem --id datamove${user} -j 2 -u mysql_dbsync_user $user $shortprog >> $dir/log/dblog.$user.log
					sem --id datamove${user} -j 2 -u rsync_homedir $user $shortprog
					sem --wait --id datamove${user}
				else
					rsync_homedir $user $shortprog
				fi
				eternallog $user
			fi
			# perform post-restore tasks
			install_ssl $user
			hosts_file $user
			apache_user_includes $user
		else
			#restore failed
			ec red "Warning: Cpanel user $user not found!" | errorlogit 2
			echo $user >> $dir/did_not_restore.txt
		fi
	else
		# if the package failed, mark as failed
		ec lightRed "Error: Did not find backup file for user $user!" | errorlogit 2
		echo $user >> $dir/did_not_restore.txt
	fi
}
