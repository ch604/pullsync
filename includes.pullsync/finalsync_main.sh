finalsync_main() { #resync data, optionally stopping services on the source server
	local choices fixmatch
	declare -a cmd options
	#check a few things before starting
	multihomedir_check
	space_check
	backup_check
	unowneddbs
	if [ "$enabledbackups" ]; then
		ec yellow "Finishing configuration of cPanel backups..."
		# shellcheck disable=SC2086
		parallel -j 100% -u 'cpbackup_finish {}' ::: $userlist
	fi

	#print the options menu and automatically align certain selections
	if [ ! "$autopilot" ]; then
		cmd=(dialog --nocancel --clear --backtitle "pullsync" --title "Final Sync Menu" --separate-output --checklist "Select options for the final sync. Sane options have been selected based on your source, but modify as needed.\n" 0 0 19)
		options=(	1 "Remove HostsCheck.php files" on
			2 "Stop services on source server (httpd, cpanel, and mail)" on
			3 "Restart services after sync" on
			4 "Add motd to source server while services stopped" on
			5 "Put up maintenance page for all traffic while services are stopped" on
			6 "Use --update for rsync" on
			7 "Exclude 'cache' from the rsync" off
			8 "Copy DNS zonefiles back to the old server" on
			9 "Scan php files for malware during sync (all users)" off
			10 "Run marill auto testing after final sync" off
			11 "Set up AutoSSL from cPanel/COMODO" off
			12 "Remove local motd for pullsync" on
			13 "Run fixperms.sh after homedir sync" off
			14 "Use --delete on the mail folder (BETA)" off
			15 "Copy remote cPanel backup destinations (e.g. S3, FTP)" off
			16 "Set domains on source server to 'remote' mail routing (BETA)" off
			17 "Skip backup of local mysql dbs before import" off
			16 "Don't use dbscan" on)
		#dont restart services or copy dns for ip swaps
		[ "$ipswap" ] && cmd[9]=$(echo "${cmd[9]}\n(3 8) IP swap selected") && options[8]=off && options[23]=off
		#turn malware scan on if there were hits during initial sync
		[ -s /root/dirty_accounts.txt ] && cmd[9]=$(echo "${cmd[9]}\n(9) Malware found in prior pullsync (/root/dirty_accounts.txt)") && options[26]=off
		#turn on autossl if there are autossls on source
		for crt in $dir/var/cpanel/ssl/installed/certs/*.crt; do openssl x509 -in $crt -issuer -noout; done | grep -q -e "cPanel, Inc." -e "Let's Encrypt" && cmd[9]=$(echo "${cmd[9]}\n(11) Source has AutoSSL issued certs") && options[32]=on
		#check for need of fixperms
		parallel -j 100% --halt now,fail=1 'fixpermscheck {}' ::: $userlist &> /dev/null
		fixmatch=$?
		[ "$fixmatch" -ge 1 ] && cmd[9]=$(echo "${cmd[9]}\n(13) Some accounts have incorrect public_html permissions (you still need to turn this on if you want to run fixperms)")
		#copy remote backup dests if anuy exist
		[ "$(\ls $dir/var/cpanel/backups/*.backup_destination 2> /dev/null)" ] && cmd[9]=$(echo "${cmd[9]}\n(15) Source using remote backup destinations") && options[44]=on
		choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
		clear
		echo $choices >> $log
		for choice in $choices; do print_next_element options $choice >> $log; done
		for choice in $choices; do
			case $choice in
				1)	doremovehc=1;;
				2)	stopservices=1;;
				3)	restartservices=1;;
				4)	remotemotd=1;;
				5)	sssh "if [[ \"\$(uname -m)\" != \"x86_64\" ]]; then wget -q -O /root/maintenance http://67.225.133.73/maintenance-32; else wget -q -O /root/maintenance http://67.225.133.73/maintenance; fi; chmod 700 /root/maintenance &> /dev/null"
					sssh "stat /root/maintenance &> /dev/null" && maintpage=1 || ec red "Could not download maintenance engine! Skipping maintenance pages...";;
				6)	rsync_update="--update";;
				7)	rsync_excludes=$(echo --exclude=cache $rsync_excludes);;
				8)	copydns=1;;
				9)	malwarescan=1; download_malscan;;
				10)	runmarill=1; download_marill;;
				11)	autossl=1;;
				12)	removemotd=1;;
				13)	fixperms=1; download_fixperms;;
				14)	maildelete=1;;
				15)	copyremotebackups=1;;
				16)	setremotemx=1;;
				17)	skipsqlzip=1;;
				18)	nodbscan=1;;
				*)	:;;
			esac
		done
		build_finalsync_message
	fi
	#if autopilot, just the basics
	[ "$autopilot" ] && rsync_update="--update" && doremovehc=1

	#ticket note
	clear
	ec lightPurple "Copy the following into your ticket:"
	(
	echo "started $scriptname $version at $starttime on $(hostname) ($cpanel_main_ip)"
	echo "synctype is $synctype. source server is $ip."
	echo "to reattach, run (screen -r $STY)."
	if [ $stopservices ]; then
		echo -e "\n* stopped services on source server and ran exim queue"
		[ $maintpage ] && echo "* started maintenance engine on source server"
		[ $restartservices ] && echo "* restarted services on source server" || echo "* DID NOT RESTART SERVICES ON SOURCE SERVER"
	else
		echo -e "\n* did not stop services on source server"
	fi
	[ $copydns ] && echo "* copied DNS to source server" || echo "* did not copy DNS to source server"
	[ "$rsync_update" = "--update" ] && echo "* used --update for rsync"
	echo $rsync_excludes | grep -q cache && echo "* excluded cache from rsync"
	[ $doremovehc ] && echo "* removed lwHostsCheck files from all users"
	[ $autossl ] && echo "* enabled AutoSSL for all users"
	[ $malwarescan ] && echo "* scanned php files on all accounts for malware"
	[ $runmarill ] && echo "* ran marill auto-testing"
	[ $copyremotebackups ] && echo "* copied remote backup destinations"
	[ $fixperms ] && echo -e "\n* RAN FIXPERMS UPON ACCOUNT ARRIVAL"
	[ $maildelete ] && echo -e "\n* USED --delete ON THE MAIL FOLDER (BETA)"
	[ $setremotemx ] && echo -e "\n* SET SOURCE SERVER TO REMOTE MX DESTINATION (BETA)"
	[ $ipswap ]  && echo -e "\n* PERFORMED AUTOMATIC IP SWAP"
	[ "$(echo $userlist | wc -w)" -gt 15 ] && echo -e "\ntruncated userlist ($(echo $userlist | wc -w)): $(echo $userlist | tr ' ' '\n' | head -15 | paste -sd' ')" || echo -e "\nuserlist ($(echo $userlist | wc -w)): $(echo $userlist | paste -sd' ')"
	) | tee -a $dir/ticketnote.txt | logit
	ec lightPurple "Stop copying now :D"

	#pull the trigger...
	ec lightRed "If errors are encountered with db dumps, you will be given the option to skip the DNS update, so don't go far!"
	ec lightBlue "Ready to begin the final sync!"
	say_ok

	#dont reboot on oom
	ec yellow "Disabling panic/reboot on oom..."
	[ "$(sysctl -n vm.panic_on_oom)" -eq 1 ] && sysctl vm.panic_on_oom=0 &> /dev/null

	#update motd and clean up extra testing files
	lastpullsyncmotd
	getreadyforparallel
	[ "$doremovehc" ] && ec yellow "Erasing HostsCheck.php files in the background..." && (remove_HostsCheck & )

	#stop services on the source server and start the maintenance engine, detect extra programs to restart for later
	if [ "$stopservices" ]; then
		if [ "$remotemotd" ]; then
			ec yellow "Adding motd to remote server..."
			sssh "echo -e '\tServices have been STOPPED for a migration final sync. Do not restart without contacting migrations.' >> /etc/motd"
		fi
		ec yellow "Suspending inbound messages on source..."
		#ec yellow "Running exim queue and suspending inbound messages on source..."
		sssh "echo 'in.smtpd : ALL : twist /bin/echo 453 System Maintenance' >> /etc/hosts.deny"
		#sssh "echo 'in.smtpd : ALL : twist /bin/echo 453 System Maintenance' >> /etc/hosts.deny; [ \$(exim -bpc) -gt 0 ] && echo \$(exim -bpc) mails in queue && exim -qf"
		ec yellow "Stopping Services..."
		sssh "[ -x /usr/local/cpanel/bin/tailwatchd ] && /usr/local/cpanel/bin/tailwatchd --disable=Cpanel::TailWatch::ChkServd || /usr/local/cpanel/libexec/tailwatchd --disable=Cpanel::TailWatch::ChkServd"
		sssh "for each in crond httpd exim cpanel; do if [ \"\$(which service 2>/dev/null)\" ]; then service \$each stop; else /etc/init.d/\$each stop; fi; done"
		echo -e "crond\nhttpd\nexim\ncpanel\n" >> $dir/stoppedservices.txt
		port_80_prog=$(sssh "netstat -tulpn" | awk -F/ '/:(80|443) / {print $NF}' | sort -u)
		if echo $port_80_prog | grep -q -E 'lsws|lshttpd|litespeed'; then
			port_80_prog=$(echo "$port_80_prog lsws lshttpd litespeed")
			echo $port_80_prog | sed 's/\ /\n/g' >> $dir/stoppedservices.txt
		fi
		[ "$port_80_prog" ] && sssh "for each in $(echo $port_80_prog); do if [ \"\$(which service 2>/dev/null)\" ]; then service \$each stop; else /etc/init.d/\$each stop; fi; done"
		sssh "for each in \/sbin\/maldet \/cpanel\/bin\/backup \/scripts\/cpbackup; do kill \$(pgrep -f \$each) 2> /dev/null; done" #send a nice kill to backup and maldet procs
		for each in /sbin/maldet /cpanel/bin/backup /scripts/cpbackup; do kill $(pgrep -f $each) 2>&1 | stderrlogit 3; done #and the same on localhost
		sssh "lsof -t -i :80 -i :443 | xargs kill 2> /dev/null" #make sure anything still running on 80 or 443 are killed
		if [ "$maintpage" ]; then
			ec yellow "Starting maintenance page engine..."
			sssh "((/root/maintenance &> /dev/null) & )"
		fi
	else
		ec yellow "Not stopping services."
	fi

	# get target ready for db restores
	prep_for_mysql_dbsync
	prep_for_pgsql_dbsync

	ec yellow "Executing final sync..."
	parallel --jobs $jobnum -u 'finalfunction {#} {} >$dir/log/looplog.{}.log' ::: $userlist &
	syncprogress $! finalfunction
	
	# sync extra dbs
	if [ -s /root/db_include.txt ]; then
		ec yellow "Syncing /root/db_include.txt..."
		dblist_restore=$(cat /root/db_include.txt)
		sanitize_dblist
		echo "$dblist_restore" > $dir/dblist.txt
		while read -r -u9 db; do
			mysql_dbsync "$db"
		done 9<$dir/dblist.txt
	fi
	ec green "Final syncs complete!"

	#cleanup functions
	if [ "$remoteea" = "EA4" ]; then
		ec yellow "Resetting .htaccess files for EA4 versions..."
		screen -S resetea4 -d -m resetea4versions
	fi
	/usr/local/cpanel/bin/ftpupdate 2>&1 | stderrlogit 3 #in case new ftp users were copied

	# if tomcat was installed or exists, restart tomcat instances
	[ -f /usr/local/cpanel/scripts/ea-tomcat85 ] && ec yellow "Restarting tomcat instances..." && /usr/local/cpanel/scripts/ea-tomcat85 all restart &> /dev/null

	#option to bail if errors, otherwise do the dns updates
	if [ ! "$autopilot" ]; then
		if [ -f $dir/missing_dbs.txt ] || [ -f $dir/dbdump_fails.txt ]; then
			[ -f $dir/missing_dbs.txt ] && ec red "Some databases were missing during final sync and were created and imported (cat $dir/missing_dbs.txt $dir/missing_dbgrants.txt)" && cat $dir/missing_dbs.txt | logit
			[ -f $dir/dbdump_fails.txt ] && ec red "Some databases failed to dump properly during the final sync and should be redumped (cat $dir/dbdump_fails.txt)" && cat $dir/dbdump_fails.txt | logit
			if yesNo "Continue with the DNS update or IP swap (if selected)?"; then
				copybackdns
			else
				ec red "Bailing! NOT updating DNS or swapping IPs! Services will be restarted only if you said you wanted to originally!"
				finalabort=1
				unset ipswap autossl runmarill copydns copyremotebackups removemotd setremotemx
			fi
		else
			copybackdns
		fi
	elif [ "$autopilot" ]; then #always continue with autopilot
		copybackdns
	fi

	#restart services
	if [ "$restartservices" ]; then
		if [ "$maintpage" ]; then
			ec yellow "Killing maintenance page engine..."
			sssh "killall /root/maintenance &> /dev/null"
			sssh "\rm -f /root/maintenance &> /dev/null"
		fi
		ec yellow "Restarting Services..."
		if echo $port_80_prog | grep -qvE 'lsws|lshttpd|litespeed'; then #only start httpd if no lsws
			sssh "/scripts/restartsrv_httpd"
		fi
		[ "$port_80_prog" ] && sssh "for each in $(echo $port_80_prog); do if [ \"\$(which service 2>/dev/null)\" ]; then service \$each start; else /etc/init.d/\$each start; fi; done"
		sssh "for each in crond exim cpanel; do if [ \"\$(which service 2>/dev/null)\" ]; then service \$each start; else /etc/init.d/\$each start; fi; done"
		sssh "sed -i '/453 System Maintenance/d' /etc/hosts.deny"
		sssh "[ -x /usr/local/cpanel/bin/tailwatchd ] && /usr/local/cpanel/bin/tailwatchd --enable=Cpanel::TailWatch::ChkServd || /usr/local/cpanel/libexec/tailwatchd --enable=Cpanel::TailWatch::ChkServd"
		sssh "/scripts/restartsrv_chkservd &> /dev/null"
		# remove motd if present on source
		sssh "grep -q 'final\ sync' /etc/motd && sed -i '/final\ sync/d' /etc/motd"
		sleep 5
	else
		ec yellow "Skipping restart of services."
		[ "$maintpage" ] && [ "$stopservices" ] && ec red "Maintenance page engine left running on source. This must be killed to start apache (killall /root/maintenance)."
	fi

	#direct mail still attempting local delivery on source to target server
	if [ "$setremotemx" ]; then
		ec yellow "Setting domains on source server to remote mail routing..."
		parallel -j 100% -u 'sssh "/usr/local/cpanel/scripts/xfertool --setupmaildest {} remote"' ::: $userlist 2>&1 | stderrlogit 3
	fi

	#start ip swap if selected
	[ "$ipswap" ] && [ ! "$autopilot" ] && ip_swap

	#autossl
	if [ "$autossl" ]; then
		ec yellow "Enabling AutoSSL and running delayed checks in the background..."
		/usr/local/cpanel/bin/whmapi1 set_autossl_provider provider=LetsEncrypt x_terms_of_service_accepted='https://letsencrypt.org/documents/LE-SA-v1.4-April-3-2024.pdf' 2>&1 | stderrlogit 3
		nohup sh -c 'sleep 300 && /usr/local/cpanel/bin/whmapi1 start_autossl_check_for_all_users' &> /dev/null & #300s allows time for propagation
	fi

	#marill
	if [ $runmarill ]; then
		getlocaldomainlist
		: > $hostsfile_alt
		ec yellow "Generating hosts file entries..."
		parallel -j 100% 'hosts_file {}' ::: $userlist
		marill_gen
	fi

	#remote backups
	if [ "$copyremotebackups" ]; then
		ec yellow "Copying remote cPanel backup destinations..."
		cp -a $dir/var/cpanel/backups/*.backup_destination /var/cpanel/backups/
	fi

	#nameserver ip refresh
	ec yellow "Refreshing WHM nameserver list..."
	/scripts/updatenameserverips

	#motd cleanup
	[ "$removemotd" ] && grep -q pullsync /etc/motd && sed -i '/pullsync/d' /etc/motd

	#re-enable reboot on oom
	ec yellow "Re-enabling panic/reboot on oom..."
	[ "$(sysctl -n vm.panic_on_oom)" -eq 0 ] && sysctl vm.panic_on_oom=1 &> /dev/null

	#print notes and errors
	ec yellow "== Actions Taken =="
	if [ "$stopservices" ]; then
		ec white "Stopped services. (cat $dir/stoppedservices.txt)"
		[ "$restartservices" ] && ec white "Restarted services." || ec white "Did not restart services."
	else
		ec white "Did not stop services."
	fi
	[ "$copydns" ] && ec white "Copied zone files back to old server." || ec white "Did not copy zone files back to old server"
	[ "$ipswap" ] && ec white "Swapped IPs between source and destination servers."
	[ $autossl ] && ec white "Turned on AutoSSL"
	[ $copyremotebackups ] && ec white "Copied remote backup configuration from source server"
	[ $removemotd ] && ec white "Removed MOTD"
	[ -f $dir/matchingchecksums.txt ] && ec green "Some tables had matching checksums and were skipped:" && cat $dir/matchingchecksums.txt | logit
	[ -f $dir/missing_dbs.txt ] && ec red "Some databases were missing during final sync and were created and imported (cat $dir/missing_dbs.txt; cat $dir/missing_dbgrants.txt)"
	[ -f $dir/dbmalware.txt ] && ec red "Some databases may have malware, which usually indicates that the CMS is totally hosed. Please check manually (cat $dir/dbmalware.txt)"
	[ -s $dir/error.log ] && ec red "There is content in $dir/error.log! (cat $dir/error.log)" && cat $dir/error.log
	[ $finalabort ] && ec red "You aborted the final sync!" && exitcleanup 120

	#print the final sync message to customer
	print_finalsync_message
}
