oldmigrationcheck() { #always run during synctype_logic, to get old ip/port and pre-sync the config folder
	ec yellow "Checking for previous migrations..."
	local choice i tempoldip tempoldport tempoldcount temporigticket
	declare -a oldlist options cmd
	# list the pullsync folders on the server into an array
	# shellcheck disable=SC2010
	mapfile -t oldlist < <(\ls -c /home/temp/ | grep "^pullsync\." | grep -v "$starttime" | head -n10)
	if [ "${#oldlist[@]}" = 0 ]; then
		# if no old migrations, skip the menu
		choice=0
	else
		# loop through the last few migrations and make a summary menu
		options=(0 "Enter new connection credentials" on)
		i=1
		for each in "${oldlist[@]}"; do
			tempoldip=$(cat "/home/temp/$each/ip.txt")
			tempoldport=$(cat "/home/temp/$each/port.txt")
			tempoldcount=$(wc -w < "/home/temp/$each/userlist.txt" 2> /dev/null || echo 0)
			options+=("$i" "${each#*.} \Z2$tempoldip:$tempoldport\Zn count: \Z2$tempoldcount\ZnZn" off)
			((i+=1))
		done
		cmd=(dialog --colors --nocancel --backtitle "pullsync" --title "Old Migrations" --radiolist "Select an old migration to pull connection details from:" 0 80 11)
		choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	fi
	clear
	# record the choice and the folder name
	echo "$choice" >> "$log"
	print_next_element options "$choice" >> "$log"
	case $choice in
		0) :;; # dont use an old migration
		*) : # set variables based on old migration selected
			olddir=/home/temp/${oldlist[(($choice-1))]}
			echo "$olddir" > "$dir/olddir.txt"
			[ -f "$olddir/ip.txt" ] && oldip=$(cat "$olddir/ip.txt")
			[ -f "$olddir/starttime.txt" ] && oldstarttime=$(cat "$olddir/starttime.txt")
			[ -f "$olddir/port.txt" ] && oldport=$(cat "$olddir/port.txt")
			[ -f "$olddir/userlist.txt" ] && oldusercount=$(wc -w < "/home/temp/$each/userlist.txt" 2> /dev/null || echo 0) && someoldusers=$(paste -sd' ' "$olddir/userlist.txt" | cut -d' ' -f1-10)
			#if an old migration was selected, reuse the already copied temp data (to be deleted/updated upon actual connection)
			ec yellow "Pre-populating config files from old directory..."
			for folder in etc opt root usr var; do
				rsync -aqH --link-dest="$olddir" "$olddir/$folder" "$dir/" --exclude=validate_license_output.txt --exclude=cpanel/users &> /dev/null
			done
			#copy nameserver_summary.txt to skip dnscheck on final sync
			[ -f "$olddir/nameserver_summary.txt" ] && cp -a "$olddir/nameserver_summary.txt" "$dir/" &> /dev/null
			;;
	esac
}
