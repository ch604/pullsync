updatesync_main() { #update sync logic. like a finalsync_main() but without stopping services.
	local choices fixmatch
	declare -a cmd options
	# check a few things and get some input before starting
	multihomedir_check
	space_check
	backup_check
	unowneddbs
	if [ "$enabledbackups" ]; then
		ec yellow "$hg Finishing configuration of cPanel backups"
		# shellcheck disable=SC2086
		parallel -j 100% -u 'cpbackup_finish {}' ::: $userlist
		writecm
	fi

	# menu for sync options
	cmd=(dialog --nocancel --clear --backtitle "pullsync" --title "Update Sync Menu" --separate-output --checklist "Select options for the update sync. Sane options have been selected based on your source, but modify as needed." 0 0 9)
	options=( 1 "Use --update for rsync" on
		2 "Exclude 'cache' from the rsync" off
		3 "Scan php files for malware during sync (users in /root/dirty_accounts.txt)" off
		4 "Run marill auto testing after sync" off
		5 "Run fixperms.sh after homedir sync" off
		6 "Use --delete on the mail folder (BETA)" off
		7 "Don't use dbscan on database copy" on
		8 "Don't backup databases before transfer" off)

	if [ -s /root/dirty_accounts.txt ]; then
		options[8]=on
		cmd[9]="${cmd[9]}\n(3) Found /root/dirty_accounts.txt"
	fi
	# shellcheck disable=SC2086
	parallel -j 100% --halt now,fail=1 'fixpermscheck {}' ::: $userlist &> /dev/null
	fixmatch=$?
	[ "$fixmatch" -ge 1 ] && cmd[9]="${cmd[9]}\n(5) Some accounts have incorrect public_html permissions (you still need to turn this on if you want to run fixperms)"

	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	echo "$choices" >> "$log"
	for choice in $choices; do
		print_next_element options "$choice" >> "$log"
		# shellcheck disable=SC2086
		case $choice in
			1) rsync_update="--update";;
			2) rsync_excludes=$(echo --exclude=cache $rsync_excludes);;
			3) malwarescan=1; download_malscan;;
			4) runmarill=1; download_marill;;
			5) fixperms=1; download_fixperms;;
			6) maildelete=1;;
			7) nodbscan=1;;
			8) skipsqlzip=1;;
			*) :;;
		esac
	done

	# print ticket note
	clear
	ec lightPurple "Copy the following into your ticket:"
	(
	echo "started $scriptname $version at $starttime on $(hostname) ($cpanel_main_ip)"
	echo "synctype is $synctype. source server is $ip."
	echo -e "to reattach, run (screen -r $STY).\n"
	[ "$rsync_update" ] && echo "* used --update for rsync"
	[ "$malwarescan" ] && echo "* scanned php files for accounts in /root/dirty_accounts.txt for malware"
	[ "$runmarill" ] && echo "* ran marill auto-testing"
	[ "$fixperms" ] && echo -e "\n* RAN FIXPERMS UPON ACCOUNT ARRIVAL"
	[ "$maildelete" ] && echo -e "\n* USED --delete ON THE MAIL FOLDER (BETA)"
	if [ "$(wc -w <<< "$userlist")" -gt 15 ]; then
		echo -e "\ntruncated userlist ($(wc -w <<< "$userlist")): $(echo "$userlist" | head -15 | tr '\n' ' ')"
	else
		echo -e "\nuserlist ($(wc -w <<< "$userlist")): $(echo "$userlist" | tr '\n' ' ')"
	fi ) | tee -a "$dir/ticketnote.txt" | logit
	ec lightPurple "Stop copying now :D"
	ec lightBlue "Ready to begin the update sync!"
	say_ok
	# start of the unattended section

	# reset the motd
	lastpullsyncmotd
	getreadyforparallel

	# get target ready for db restores
	prep_for_mysql_dbsync
	prep_for_pgsql_dbsync

	# execute the transfer
	ec yellow "Executing update sync..."
	# shellcheck disable=SC2016,SC2086
	parallel --jobs "$jobnum" -u 'finalfunction {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
	syncprogress $! finalfunction

	# sync extra dbs
	if [ -f /root/db_include.txt ]; then
		ec yellow "Syncing /root/db_include.txt..."
		dblist_restore=$(cat /root/db_include.txt)
		sanitize_dblist
		echo "$dblist_restore" > "$dir/dblist.txt"
		while read -r -u9 db; do
			mysql_dbsync "$db"
		done 9< "$dir/dblist.txt"
	fi
	ec green "File syncs complete!"

	# cleanup functions
	if [ "$remoteea" = "EA4" ]; then
		ec yellow "Resetting .htaccess files for EA4 versions..."
		screen -S resetea4 -d -m resetea4versions
	fi
	/usr/local/cpanel/bin/ftpupdate 2>&1 | stderrlogit 3 #in case new ftp users were copied

	# if tomcat was installed or exists, restart tomcat instances
	[ -f /scripts/ea-tomcat85 ] && ec yellow "Restarting tomcat instances..." && /scripts/ea-tomcat85 all restart &> /dev/null

	# marill
	if [ "$runmarill" ]; then
		getlocaldomainlist
		: > "$hostsfile_alt"
		ec yellow "Generating hosts file entries..."
		# shellcheck disable=SC2086
		parallel -j 100% 'hosts_file {}' ::: $userlist
		marill_gen
	fi
}
