optimize_menu(){ #run outside of matching_menu() in case version matching is not needed, but optimizations are wanted
	local cmd=(dialog --clear --backtitle "pullsync" --title "Optimization Menu" --separate-output --checklist "Select options for server optimization. Sane options were selected based on your configuration:\n" 0 0 6)
	local options=( 1 "Install mod_http2 for EA4" on
			2 "Install memcached and modules" on
			3 "Use FPM for all accounts (converts migrated domains!)" off
			4 "Turn on keepalive, mod_expires, and mod_deflate" off
			5 "Security tweaks" off
			6 "Install mod_pagespeed" off)

	# turn things on front to back
	#SSP tweaks (12 13 14)
	if grep -E -q ^SMTP_BLOCK\ ?=\ ?[\'\"]1[\'\"]$ $dir/etc/csf/csf.conf || grep -E -q ^smtpmailgidonly=1$ $dir/var/cpanel/cpanel.config; then
		options[14]=on && cmd[8]=`echo "${cmd[8]}\n(5) SSP tweaks recommended since smtp tweak enabled"`
	fi

	# turn things off back to front
	#basic optimizations (9 10 11)
	if [ ! "$localea" = "EA4" ]; then
		unset options[11] options[10] options[9] && cmd[8]=`echo "${cmd[8]}\n(4) Basic optimization tweaks are not compatible with EA3"`
	fi

	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	[ $? != 0 ] && exitcleanup 99
	clear
	echo $choices >> $log
	for choice in $choices; do print_next_element options $choice >> $log; done
	for choice in $choices; do
		case $choice in
			1)	modhttp2=1;;
			2)	memcache=1;;
			3)	fpmdefault=1;;
			4)	basicoptimize=1;;
			5)	ssp_tweaks=1;;
			6)	pagespeed=1;;
			*)	:;;
		esac
	done
}
