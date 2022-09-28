finalfunction(){ #$1 is position, $2 is username. this is where the actual final sync happens. programmed with global variables and argument import so it can be looped in parallel.
	local user=$2
	local progress="$1/$user_total | $user:"
	#get some rare stuff out of the way first
	if [ "$dopgsync" = 1 ]; then
		if [[ -f "$dir/var/cpanel/databases/$user.json" ]]; then
			local pgdbs=`cat $dir/var/cpanel/databases/$user.json | python -c 'import sys,json; dbs=json.load(sys.stdin)["PGSQL"]["dbs"].keys() ; print "\n".join(dbs)'`
		elif [ -f "$dir/var/cpanel/databases/$user.yaml" ]; then
			local pgdbs=`cat $dir/var/cpanel/databases/$user.yaml | python -c 'import sys,yaml; dbs=yaml.load(sys.stdin, Loader=yaml.FullLoader)["PGSQL"]["dbs"].keys() ; print "\n".join(dbs)'`
		fi
		local pgdbcount=`echo $pgdbs |wc -w`
		if [[ $pgdbcount -gt 0 ]]; then
			for db in $pgdbs; do
				ec blue "$progress Importing pgsql db $db..."
				sssh "pg_dump --clean -U postgres $db > $remote_tempdir/$db.psql"
				rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:$remote_tempdir/$db.psql $dir/pgdumps/
				pg_dump --clean -U postgres $db > $dir/pre_pgdumps/$db.psql
				psql --quiet -U postgres -f $dir/pgdumps/$db.psql -d $db
			done
		fi
	fi
	if [ -f "/var/cpanel/datastore/$user/mailman-list-usage" ] && [ $(cat /var/cpanel/datastore/$user/mailman-disk-usage) -gt 0 ]; then
		local mailinglists=`cat /var/cpanel/datastore/$user/mailman-list-usage |cut -d: -f1`
		ec white "$progress Syncing mailman lists..."
		for list in $mailinglists; do
			# list settings in /usr/local/cpanel/3rdparty/mailman/lists/$list
			rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:/usr/local/cpanel/3rdparty/mailman/lists/$list /usr/local/cpanel/3rdparty/mailman/lists/
			# archive data is in /usr/local/cpanel/3rdparty/mailman/archives/{private,public}/$list{,.mbox}
			rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:"/usr/local/cpanel/3rdparty/mailman/archives/private/$list{,.mbox}" /usr/local/cpanel/3rdparty/mailman/archives/private/
			rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:"/usr/local/cpanel/3rdparty/mailman/archives/public/$list{,.mbox}" /usr/local/cpanel/3rdparty/mailman/archives/public/ 2>&1 | stderrlogit 4
		done
	fi
	#the meaty core
	local shortprog=$(echo "$progress" | awk '{print $1}')
	sem --id datamove${user} -j 2 -u mysql_dbsync_2 $user $shortprog >> $dir/log/dblog.$user.log
	sem --id datamove${user} -j 2 -u rsync_homedir $user $shortprog
	sem --wait --id datamove${user}
	echo $user >> $dir/final_complete_users.txt
}
