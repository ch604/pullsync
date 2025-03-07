package_accounts() { #runs packagefuncion() in parallel and starts the syncprogress() command to display the syncing info
	ec yellow "Packaging cpanel accounts externally and restoring on local server..."

	# blank the hostsfile temp files
	: > "$hostsfile"
	: > "$hostsfile_alt"

	# make the folder for cpmove files
	mkdir -p "$dir/cpmovefiles"

	# set old main ip for checking restoration to dedicated ip
	old_main_ip=$(awk '/ADDR [0-9]/ {print $2}' "$dir/etc/wwwacct.conf" | tr -d '\n')
	[ ! "$old_main_ip" ] && old_main_ip=$(cat "$dir/var/cpanel/mainip")

	# get ssl data for restore during loop. use custom ___ terminator for good awk
	ec yellow "Getting SSL components..."
	sssh "whmapi1 --output=json fetch_vhost_ssl_components" | jq '.data.components[] | "\(.servername)___\(.certificate)___\(.key)___\(.cabundle)"' | tr -d \" > "$dir/ssls.txt" 2> /dev/null
	chmod 400 "$dir/ssls.txt"

	# prepare target for db restores
	prep_for_mysql_dbsync
	prep_for_pgsql_dbsync

	# shellcheck disable=SC2016,SC2086
	parallel --jobs $jobnum -u 'packagefunction {#} {} >$dir/log/{}.loop.log' ::: $userlist &
	syncprogress $! packagefunction
}
