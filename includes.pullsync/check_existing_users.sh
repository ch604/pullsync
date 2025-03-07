check_existing_users() { #warn if any users exist on target server
	local current_user_count
	current_user_count=$(find /var/cpanel/users/ -maxdepth 1 -type f -printf "%f\n" | grep -Ev "^HASH" | grep -cEvx "${badusers}")
	if [ "$current_user_count" -gt 0 ] ; then
		ec lightRed "Warning: Detected $current_user_count users already exist on this server! Version changes will affect them."
		if [ "$autopilot" ] && [ "$do_installs" ]; then
			ec lightRed "You asked me to match versions on autopilot, and users already exist here. Run pullsync manually instead!"
			exitcleanup 9
		fi
	fi
}
