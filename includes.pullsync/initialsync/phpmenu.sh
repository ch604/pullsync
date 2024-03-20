phpmenu(){ #menu to select how to run EA. auto selects option based on what is set source and target
	local cmd=(dialog --nocancel --clear --backtitle "pullsync" --title "EasyApache Menu" --radiolist "Select options for EasyApache profile matching. Sane options have been selected based on your source and target, but modify as needed.\n\nLocal EA : $localea\nRemote EA: $remoteea\n\nLocal PHP : $localphp\nRemote PHP: $remotephp\n\nLocal Handler : $localphphandler\nRemote Handler: $remotephphandler\n\nKeep in mind that if remote profile conversion fails, a default profile will be installed. The script will always attempt to adjust the default PHP version if EA4 is the target and EA is not skipped. If the source PHP version is too low or otherwise not available, 8.1 will be used as the default." 0 0 6)
	local options=( 1 "Skip EA and PHP settings matching" off
			2 "Install remote EA3/4 profile" off
			3 "Install default EA4 profile" off
			4 "Skip EA but match PHP settings anyway" off)
	[ "$remoteea" = "EA4" ] && options[5]=on || options[8]=on
	if [ "$(rpm --eval %rhel)" -ge 9 ] && [ "$remoteea" = "EA4" ] && ! sssh "/usr/local/cpanel/bin/rebuild_phpconf --available" | grep -q php8; then
		options[5]=off && options[8]=on && cmd[8]=`echo "${cmd[8]}\n\nTarget is el9+ and source server does not have php8x! You should install the default EA4 profile!"`
	fi

	local choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	echo $choice >> $log
	print_next_element options $choice >> $log
	clear
	case $choice in
		2)	ea=1
			ea4profileconversion
			matchhandler=1
			apacheprepostcheck;;
		3)	defaultea4=1
			ea=1;;
		4)	noeaextras=1
			matchhandler=1
			unset ea migrateea4 matchhandler fpmconvert ea3;;
		*)	unset ea migrateea4 matchhandler fpmconvert ea3;;
	esac
}
