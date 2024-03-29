check_existing_users() { #warn if any users exist on target server
	local currentUserCount=$(\ls -A /var/cpanel/users/ | egrep -v "^HASH" | egrep -vx "${badusers}" | wc -l)
	if [[ $currentUserCount > 0 ]] ; then
		ec lightRed "Warning: Detected $currentUserCount users already exist on this server! Version changes will affect them."
		if [ "$autopilot" ] && [ $do_installs ]; then
			ec lightRed "You asked me to match versions on autopilot, and users already exist here. Run pullsync manually instead!"
			exitcleanup 9
		fi
	fi
}
