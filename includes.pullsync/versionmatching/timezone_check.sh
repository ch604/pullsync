timezone_check() { #compare timezones and ask to match them
	[ -f $dir/etc/sysconfig/clock ] && remotetimezonefile=`cat $dir/etc/sysconfig/clock | grep ^ZONE | cut -d\" -f2` || remotetimezonefile=`sssh "[ -x /bin/timedatectl ] && timedatectl | grep zone\: | cut -d\: -f2 | awk '{print $1}'"`
	[ -f /etc/sysconfig/clock ] && localtimezonefile=`cat /etc/sysconfig/clock | grep ^ZONE | cut -d\" -f2` || localtimezonefile=`[ -x /bin/timedatectl ] && timedatectl | grep zone\: | cut -d\: -f2 | awk '{print $1}'`
	remotetimezone=`sssh "date +%z"`
	localtimezone=`date +%z`
	ec white "Local timezone:	${localtimezone} (${localtimezonefile})"
	ec white "Remote timezone:	${remotetimezone} (${remotetimezonefile})"
	if ! [ -z "${remotetimezone}" -o -z "${localtimezone}" -o -z "${remotetimezonefile}" -o -z "${localtimezonefile}" ]; then
		if [ "${localtimezone}" = "${remotetimezone}" ]; then
			ec green "Timezones match (${localtimezone})."
		elif [ -f /usr/share/zoneinfo/${remotetimezonefile} ]; then
			if [ $autopilot ]; then #autopilot will only use this function if do_installs is set
				matchtimezone=1
			fi
		else
			ec red "Unable to match timezones automatically, /usr/share/zoneinfo/${remotetimezonefile} does not exist. Skipping."
		fi
	else
		ec red "Some variables failed to populate, skipping timezone changes."
	fi
}
