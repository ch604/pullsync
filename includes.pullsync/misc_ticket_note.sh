misc_ticket_note() { #ticket note for other sync types
	ec lightPurple "Copy the following into your ticket:"
	# start subshell
	(
	echo "started $scriptname $version at $starttime on $(hostname) ($cpanel_main_ip)"
	echo "synctype is $synctype. source server is $ip."
	echo "to reattach, run (screen -r $STY)."
	if [[ ! "$synctype" = "versionmatching" ]]; then
		#only run this part for non-versionmatching
		if [ "$(wc -w <<< "$userlist")" -gt 15 ]; then
			echo -e "\ntruncated userlist ($(wc -w <<< "$userlist")): $(tr ' ' '\n' <<< "$userlist" | head -15 | paste -sd' ')"
		else
			echo -e "\nuserlist ($(wc -w <<< "$userlist")): $(paste -sd' ' <<< "$userlist")"
		fi
	fi
	) | tee -a "$dir/ticketnote.txt" | logit # end subshell for tee to ticketnote
	ec lightPurple "Stop copying now :D"
	ec green "Ready to go!"
	say_ok
}
