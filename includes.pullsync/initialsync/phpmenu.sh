phpmenu(){ #menu to select how to run EA. auto selects option based on what is set source and target
	local cmd=(dialog --nocancel --clear --backtitle "pullsync" --title "EasyApache Menu" --radiolist "Select options for EasyApache profile matching. Sane options have been selected based on your source and target, but modify as needed.\n\nLocal EA : $localea\nRemote EA: $remoteea\n\nLocal PHP : $localphp\nRemote PHP: $remotephp\n\nLocal Handler : $localphphandler\nRemote Handler: $remotephphandler\n\nKeep in mind that if remote profile conversion fails, a default profile will be installed. The script will always attempt to adjust the default PHP version if EA4 is the target and EA is not skipped. If the source PHP version is too low or otherwise not available, 7.3 will be used as the default." 0 0 6)
	local options=( 1 "Skip EA and PHP settings matching" off
			2 "Install remote EA3/4 profile" off
			3 "Install default EA4 profile" off
			4 "Skip EA but match PHP settings anyway" off)
	[ "$remoteea" = "EA4" ] && options[5]=on || options[8]=on
	local choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	echo $choice >> $log
	print_next_element options $choice >> $log
	clear
	case $choice in
		2)	ea=1
			ea4profileconversion
			ea4phphandlercompare
			apacheprepostcheck;;
		3)	defaultea4=1
			ea=1;;
		4)	noeaextras=1
			unset ea migrateea4 matchhandler fcgiconvert ea3;;
		*)	unset ea migrateea4 matchhandler fcgiconvert ea3;;
	esac
}
