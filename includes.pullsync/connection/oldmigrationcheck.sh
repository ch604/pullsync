oldmigrationcheck() { #always run during synctype_logic, to get old ip/port and pre-sync the config folder
	ec yellow "Checking for previous migrations..."
	# list the pullsync folders on the server into an array
	local oldlist=($(ls -c /home/temp/ | grep "^pullsync\." | grep -v "$starttime" | head -n10))
	if [ ${#oldlist[@]} = 0 ]; then
		# if no old migrations, skip the menu
		local choice=0
	else
		# loop through the last few migrations and make a summary menu
		local options=(0 "Enter new connection credentials" on)
		local i=1
		for each in ${oldlist[@]}; do
			local tempoldip=$(cat /home/temp/$each/ip.txt)
			local tempoldport=$(cat /home/temp/$each/port.txt)
			local tempoldcount=$(cat /home/temp/$each/userlist.txt | wc -w)
			local temporigticket=$(cat /home/temp/$each/ticketnumber)
			options+=($i "${each#*.} \Z2$tempoldip:$tempoldport\Zn count: \Z2$tempoldcount\Zn ticket: \Z2$temporigticket\Zn" off)
			let i+=1
		done
		local cmd=(dialog --colors --nocancel --backtitle "pullsync" --title "Old Migrations" --radiolist "Select an old migration to pull connection details from:" 0 80 11)
		local choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	fi
	clear
	# record the choice and the folder name
	echo $choice >> $log
	print_next_element options $choice >> $log
	case $choice in
		0) :;; # dont use an old migration
		*) # set variables based on old migration selected
			olddir=/home/temp/${oldlist[(($choice-1))]}
			echo $olddir > $dir/olddir.txt
			[ -f $olddir/ip.txt ] && oldip=$(cat $olddir/ip.txt)
			[ -f $olddir/starttime.txt ] && oldstarttime=$(cat $olddir/starttime.txt)
			[ -f $olddir/port.txt ] && oldport=$(cat $olddir/port.txt)
			[ -f $olddir/userlist.txt ] && oldusercount=$(cat $olddir/userlist.txt |wc -w) && someoldusers=$(cat $olddir/userlist.txt | tr '\n' ' '| cut -d' ' -f1-10)
			#if an old migration was selected, reuse the already copied temp data (to be deleted/updated upon actual connection)
			ec yellow "Pre-populating config files from old directory..."
			for folder in etc opt root usr var; do
				rsync -aqH $olddir/$folder $dir/ --exclude=validate_license_output.txt --exclude=cpanel/users &> /dev/null
			done
			#copy nameserver_summary.txt to skip dnscheck on final sync
			[ -f $olddir/nameserver_summary.txt ] && cp -a $olddir/nameserver_summary.txt $dir/ &> /dev/null
			;;
	esac
}
