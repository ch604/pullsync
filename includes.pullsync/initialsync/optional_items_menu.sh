optional_items_menu(){ #additional options for initial syncs
	local cmd=(dialog --clear --backtitle "pullsync" --title "Optional Items" --separate-output --checklist "Select additional optional items for this sync. Sane options were selected based on your source and target setup:\n" 0 0 10)
	local options=(	1 "Comment out user crons during restore" on
			2 "Restore sites to dedicated IP addresses" off
			3 "Scan php files for malware during initial sync" on
			4 "Run marill automated testing after initial sync" on
			5 "Add motd line for in-progress migration" on
			6 "Use --dbbackup=schema for pkgacct" off
			7 "Run fixperms for migrated accounts" off
			8 "Convert Roundcube MySQL to sqlite on source" off
			9 "Skip sql backup before import" off)

	#dedi ip check (3 4 5)
	if [ ! "$synctype" = "single" ]; then
		local source_main_ip=`cat $dir/etc/wwwacct.conf|grep "ADDR\ [0-9]" | awk '{print $2}' | tr -d '\n'`
		local dedicated_ips=""
		for user in $userlist; do dedicated_ips="$dedicated_ips `grep ^IP\= $dir/var/cpanel/users/$user |grep -v $source_main_ip | cut -d= -f2`"; done
		local source_ip_usage=`echo $dedicated_ips |tr ' ' '\n' |sort |uniq |wc -w`
		local ips_free=`/usr/local/cpanel/bin/whmapi1 --output=json listips | python -c 'import sys,json; data=json.load(sys.stdin)["data"]
for ip in data["ip"]:
 if ip["mainaddr"] == 0:
  print ip["used"]' | grep 0 | wc -l`
		if [[ $source_ip_usage -le $ips_free ]] && [[ $source_ip_usage -ne 0 ]]; then
			options[5]=on
			cmd[8]=`echo "${cmd[8]}\n(2) There seem to be enough free IPs for this migration\n    (source used: $source_ip_usage; target free: $ips_free)"`
		else
			local unsetdedipcheck=1
		fi
	fi

	#phpscan (6 7 8) && marill (9 10 11)
	[ "$synctype" = "skeletons" ] && options[8]=off && options[11]=off && cmd[8]=`echo "${cmd[8]}\n(3,4) No phpscan or marill needed on skeleton syncs"`

	#motd (12 13 14)
	grep -q pullsync /etc/motd && options[14]=off && cmd[8]=`echo "${cmd[8]}\n(4) motd for pullsync already exists"`

	#dbbackup schema (15 16 17)
	sssh "/scripts/pkgacct --help | grep -q -e --dbbackup=" && options[17]=on && cmd[8]=`echo "${cmd[8]}\n(5) Source server supports dbbackup argument"`

	#fixperms (18 19 20)
	for user in $userlist; do
		[[ ! "$(sssh "stat /home/$user/public_html" | grep Uid | awk -F'[(|/|)]' '{print $2, $6, $9}')" =~ 751\ +$user\ +nobody ]] && local fixmatch=1
	done
	[ $fixmatch ] && cmd[8]=`echo "${cmd[8]}\n(7) Some accounts have incorrect public_html permissions (you still need to turn this on if you want to run fixperms)"` && unset fixmatch

	#rcube (21 22 23)
	[ ! "$synctype" = "single" ] && sssh "mysql -Nse 'show databases'" | grep -q ^roundcube$ && grep -q ^skiproundcube=0$ $dir/var/cpanel/cpanel.config && sssh "[ -f /scripts/convert_roundcube_mysql2sqlite ]" && options[23]=on && cmd[8]=`echo "${cmd[8]}\n(8) Source server has roundcube MySQL DB and can be converted"`

	#NOW SAFE TO UNSET THINGS
	#dedi ip check (3 4 5)
	if [ "$unsetdedipcheck" ]; then
		unset options[5] options[4] options[3]
		cmd[8]=`echo "${cmd[8]}\n(2) This server does not have enough dedicated IPs\n    (source used: $source_ip_usage; target free: $ips_free)"`
	fi

	#print the menu
	cmd[8]=`echo "${cmd[8]}\n\nPressing Cancel will be the same as saying 'no' to all options."`
	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	echo $choices >> $log
	for choice in $choices; do print_next_element options $choice >> $log; done
	for choice in $choices; do
		case $choice in
			1) comment_crons=1;;
			2) ded_ip_check=1;;
			3) malwarescan=1; download_malware;;
			4) runmarill=1; download_marill;;
			5) addmotd=1;;
			6) dbbackup_schema=1;;
			7) fixperms=1; download_fixperms;;
			8) rcubesqlite=1;;
			9) skipsqlzip=1;;
			*) :;;
		esac
	done
	clear
}
