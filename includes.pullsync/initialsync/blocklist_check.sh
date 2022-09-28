blocklist_check() { #check for blocklist hits of target ip
	wget -q -O $dir/blcheck https://raw.githubusercontent.com/ch604/blcheck/master/blcheck
	ec yellow "Checking target IP against blocklists..."
	if [ -f /var/cpanel/cpnat ] && grep -Eq ^$cpanel_main_ip\ [0-9]+ /var/cpanel/cpnat; then
		blcheckip=$(grep -E ^$cpanel_main_ip\ [0-9]+ /var/cpanel/cpnat | awk '{print $2}')
	else
		blcheckip=$cpanel_main_ip
	fi
	bash $dir/blcheck -q $blcheckip
	local hits=$?
	if [ $hits -gt 0 ]; then
		ec red "$blcheckip is listed on $hits blocklists! Please investigate further! (cat $dir/blcheck_blocklists.txt)" | errorlogit 2
		mv ~/blcheck_blocklists.txt $dir/
		sed -i '/'$blcheckip'/d' $dir/blcheck_blocklists.txt
	fi
}
