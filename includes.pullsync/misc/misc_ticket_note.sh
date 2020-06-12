misc_ticket_note() { #ticket note for other sync types
	ec lightPurple "Copy the following into your ticket:"
	# start subshell
	(
	echo "started $scriptname $version at $starttime on `hostname` ($cpanel_main_ip)"
	echo "synctype is $synctype. source server is $ip."
	echo "to reattach, run (screen -r $STY)."
	if [[ ! "$synctype" = "versionmatching" ]]; then
		#only run this part for non-versionmatching
		[ $(echo $userlist | wc -w) -gt 15 ] && echo -e "\ntruncated userlist ($(echo $userlist | wc -w)): $(echo $userlist | head -15 | tr '\n' ' ')" || echo -e "\nuserlist ($(echo $userlist | wc -w)): $(echo $userlist | tr '\n' ' ')"
	fi
	) | tee -a $dir/ticketnote.txt | logit # end subshell for tee to ticketnote
	ec lightPurple "Stop copying now :D"
	ec green "Ready to go!"
	say_ok
}
