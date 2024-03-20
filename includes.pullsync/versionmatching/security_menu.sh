security_menu() { #run outside of matching_menu() in case version matching is not needed, but security options are wanted
	local cmd=(dialog --clear --backtitle "pullsync" --title "Security Menu" --separate-output --checklist "Select options for server security. Sane options were selected based on your configuration:\n" 0 0 6)
	local options=( 1 "Enable LW mod_security ruleset (fight intrusion)" off
			2 "Enable mod_evasive (fight ddos)" off
			3 "Enable mod_reqtimeout (fight slowloris)" on
			4 "Disable mod_userdir (fight XSS)" on)

	# turn things on front to back
	#OWASP (0 1 2)
	if [ $(/usr/local/cpanel/bin/whmapi1 modsec_is_installed | awk '/installed: / {print $2}') -eq 1 ]; then
		if ! /usr/local/cpanel/bin/whmapi1 modsec_get_vendors | awk '/enabled: / {print $2}' | grep -q 1 && ! rpm --quiet -q serversecure-modsec2-rules && ! rpm --quiet -q lp-modsec2-rules-ea4; then
			#all modsec rules are off! DO SOMETHING!
			options[2]=on && cmd[8]=`echo "${cmd[8]}\n(1) modsec rules are DISABLED"`
		else
			#use a variable to avoid two more whmapi1 calls
			local modsecon=1
		fi
	fi

	# turn things off back to front
	#mod_userdir (9 10 11)
	if rpm --quiet -q ea-apache24-mod_mpm_itk || rpm --quiet -q ea-apache24-mod_ruid2 || rpm --quiet -q ea-ruby24-mod_passenger || rpm --quiet -q ea-apache24-mod-passenger; then
		unset options[9] options[10] options[11] && cmd[8]=`echo "${cmd[8]}\n(4) mod_userdir already disabled"`
	fi

	#mod_reqtimeout (6 7 8)
	if rpm --quiet -q ea-apache24-mod_reqtimeout; then
		unset options[6] options[7] options[8] && cmd[8]=`echo "${cmd[8]}\n(3) mod_reqtimeout already enabled"`
	fi

	#mod_evasive (3 4 5)
	if rpm --quiet -q ea-apache24-mod_evasive; then
		unset options[3] options[4] options[5] && cmd[8]=`echo "${cmd[8]}\n(2) mod_evasive already enabled"`
	fi

	#OWASP (0 1 2)
	if [ $modsecon ]; then
		unset options[0] options[1] options[2] && cmd[8]=`echo "${cmd[8]}\n(1) modsec rules already enabled"`
	fi

	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	[ $? != 0 ] && exitcleanup 99
	clear
	echo $choices >> $log
	for choice in $choices; do print_next_element options $choice >> $log; done
	for choice in $choices; do
		case $choice in
			1)	enable_modsec=1;;
			2)	enable_modevasive=1;;
			3)	enable_modreqtimeout=1;;
			4)	disable_moduserdir=1;;
			*)	:;;
		esac
	done
}
