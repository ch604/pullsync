security_menu() { #run outside of matching_menu() in case version matching is not needed, but security options are wanted
	local cmd=(dialog --clear --backtitle "pullsync" --title "Security Menu" --separate-output --checklist "Select options for server security. Sane options were selected based on your configuration:\n" 0 0 6)
	local options=(	1 "Enable mod_evasive (fight ddos)" off
			2 "Enable mod_reqtimeout (fight slowloris)" on
			3 "Disable mod_userdir (fight XSS)" on)

	# turn things on front to back

	# turn things off back to front
	#mod_userdir (6 7 8)
	if rpm --quiet -q ea-apache24-mod_mpm_itk || rpm --quiet -q ea-apache24-mod_ruid2 || rpm --quiet -q ea-ruby24-mod_passenger; then
		unset options[6] options[7] options[8] && cmd[8]=`echo "${cmd[8]}\n(3) mod_userdir already disabled"`
	fi

	#mod_reqtimeout (3 4 5)
	if rpm --quiet -q ea-apache24-mod_reqtimeout; then
		unset options[3] options[4] options[5] && cmd[8]=`echo "${cmd[8]}\n(2) mod_reqtimeout already enabled"`
	fi

	#mod_evasive (0 1 2)
	if rpm --quiet -q ea-apache24-mod_evasive; then
		unset options[0] options[1] options[2] && cmd[8]=`echo "${cmd[8]}\n(1) mod_evasive already enabled"`
	fi

	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	[ $? != 0 ] && exitcleanup 99
	clear
	echo $choices >> $log
	for choice in $choices; do print_next_element options $choice >> $log; done
	for choice in $choices; do
		case $choice in
			1)	enable_modevasive=1;;
			2)	enable_modreqtimeout=1;;
			3)	disable_moduserdir=1;;
			*)	:;;
		esac
	done
}
