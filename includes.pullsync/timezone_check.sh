timezone_check() { #compare timezones and ask to match them
	[ -f "$dir/etc/sysconfig/clock" ] && remotetimezonefile=$(awk -F\" '/^ZONE/ {print $2}' "$dir/etc/sysconfig/clock")
	[ ! "$remotetimezonefile" ] && remotetimezonefile=$(sssh "[ -x /bin/timedatectl ] && timedatectl" | awk '/zone:/ {print $3}')
	[ -f /etc/sysconfig/clock ] && localtimezonefile=$(awk -F\" '/^ZONE/ {print $2}' /etc/sysconfig/clock)
	[ ! "$localtimezonefile" ] && localtimezonefile=$([ -x /bin/timedatectl ] && timedatectl | awk '/zone:/ {print $3}')
	remotetimezone=$(sssh "date +%z")
	localtimezone=$(date +%z)
	# after this point, we only continue if on autopilot, since we call this function for the matching_menu()
	[ ! "$autopilot" ] && return
	ec white "Local timezone:	$localtimezone ($localtimezonefile)"
	ec white "Remote timezone:	$remotetimezone ($remotetimezonefile)"
	if [ "${remotetimezone}" ] && [ "$localtimezone" ] && [ "$remotetimezonefile" ] && [ "$localtimezonefile" ]; then
		if [ "$localtimezone" = "$remotetimezone" ]; then
			ec green "Timezones match ($localtimezone)."
		elif [ -f "/usr/share/zoneinfo/$remotetimezonefile" ] && [ "$autopilot" ]; then
			matchtimezone=1
		else
			ec red "Unable to match timezones automatically, /usr/share/zoneinfo/$remotetimezonefile does not exist. Skipping."
		fi
	else
		ec red "Some variables failed to populate, skipping timezone changes."
	fi
}
