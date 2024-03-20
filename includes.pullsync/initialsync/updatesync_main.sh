updatesync_main() { #update sync logic. like a finalsync_main() but without stopping services.
	# check a few things and get some input before starting
	multihomedir_check
	space_check
	backup_check
	unowneddbs
	mysql_listgen
	[ $enabledbackups ] && cpbackup_finish

	# menu for sync options
	local cmd=(dialog --nocancel --clear --backtitle "pullsync" --title "Update Sync Menu" --separate-output --checklist "Select options for the update sync. Sane options have been selected based on your source, but modify as needed." 0 0 9)
	local options=( 1 "Use --update for rsync" on
		2 "Exclude 'cache' from the rsync" off
		3 "Scan php files for malware during sync (users in /root/dirty_accounts.txt)" off
		4 "Run marill auto testing after sync" off
		5 "Run fixperms.sh after homedir sync" off
		6 "Use --delete on the mail folder (BETA)" off
		7 "Don't use dbscan on database copy" on
		8 "Don't backup databases before transfer" off)

	[ -s /root/dirty_accounts.txt ] && options[8]=on && cmd[9]=`echo "${cmd[9]}\n(3) Found /root/dirty_accounts.txt"`
	for user in $userlist; do
		[[ ! "$(sssh "stat /home/$user/public_html" | awk -F'[(|/|)]' '/Uid/ {print $2, $6, $9}')" =~ 751\ +$user\ +nobody ]] && local fixmatch=1
	done
	[ $fixmatch ] && cmd[9]=`echo "${cmd[9]}\n(5) Some accounts have incorrect public_html permissions (you still need to turn this on if you want to run fixperms)"` && unset fixmatch

	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	echo $choices >> $log
	for choice in $choices; do print_next_element options $choice >> $log; done
	for choice in $choices; do
		case $choice in
			1) rsync_update="--update";;
			2) rsync_excludes=`echo --exclude=cache $rsync_excludes`;;
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
	echo "started $scriptname $version at $starttime on `hostname` ($cpanel_main_ip)"
	echo "synctype is $synctype. source server is $ip."
	echo -e "to reattach, run (screen -r $STY).\n"
	[ "$rsync_update" = "--update" ] && echo "* used --update for rsync"
	[ $malwarescan ] && echo "* scanned php files for accounts in /root/dirty_accounts.txt for malware"
	[ $runmarill ] && echo "* ran marill auto-testing"
	[ $fixperms ] && echo -e "\n* RAN FIXPERMS UPON ACCOUNT ARRIVAL"
	[ $maildelete ] && echo -e "\n* USED --delete ON THE MAIL FOLDER (BETA)"
	[ $(echo $userlist | wc -w) -gt 15 ] && echo -e "\ntruncated userlist ($(echo $userlist | wc -w)): $(echo $userlist | head -15 | tr '\n' ' ')" || echo -e "\nuserlist ($(echo $userlist | wc -w)): $(echo $userlist | tr '\n' ' ')"
	) | tee -a $dir/ticketnote.txt | logit
	ec lightPurple "Stop copying now :D"
	ec lightBlue "Ready to begin the update sync!"
	say_ok
	# start of the unattended section

	# reset the motd
	lastpullsyncmotd

	# get target ready for db restores
	prep_for_mysql_dbsync
	if sssh "pgrep postgres &> /dev/null" && pgrep postgres &> /dev/null; then
		dopgsync=1
		mkdir -p -m600 $dir/pgdumps
		mkdir -p -m600 $dir/pre_pgdumps/
		sssh "mkdir -p -m600 $remote_tempdir 2> /dev/null"
	fi

	# set variables for progress display
	user_total=`echo $userlist |wc -w`
	> $dir/final_complete_users.txt
	start_disk=0
	homemountpoints=$(for each in $(echo $localhomedir); do findmnt -nT $each | awk '{print $1}'; done | sort -u)
	for each in $(echo $homemountpoints); do
		local z=$(df $each | tail -n1 | awk '{print $3}')
		start_disk=$(( $start_disk + $z ))
	done
	expected_disk=$(( $start_disk + $finaldiff ))

	# store refreshdelay so parallel can read it
	echo "$refreshdelay" > $dir/refreshdelay

	# execute the transfer
	ec yellow "Executing update sync..."
	parallel --jobs $jobnum -u 'finalfunction {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
	finalprogress $!

	# sync extra dbs
	if [ -f /root/db_include.txt ]; then
		ec yellow "Syncing /root/db_include.txt..."
		dblist_restore=`cat /root/db_include.txt`
		sanitize_dblist
		parallel_mysql_dbsync
	fi
	ec green "File syncs complete!"

	# cleanup functions
	if [ "$localea" = "EA4" ] && [ "$remoteea" = "EA4" ]; then
		ec yellow "Resetting .htaccess files for EA4 versions..."
		screen -S resetea4 -d -m resetea4versions
	fi
	/usr/local/cpanel/bin/ftpupdate 2>&1 | stderrlogit 3 #in case new ftp users were copied

	# if tomcat was installed or exists, restart tomcat instances
	[ -f /usr/local/cpanel/scripts/ea-tomcat85 ] && ec yellow "Restarting tomcat instances..." && /usr/local/cpanel/scripts/ea-tomcat85 all restart &> /dev/null

        # marill
        if [ $runmarill ]; then
                getlocaldomainlist
                > $hostsfile_alt
                for user in $userlist; do
                        hosts_file $user &> /dev/null
                done
                marill_gen
        fi
}
