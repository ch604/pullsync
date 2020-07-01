blacklist_check() { #check for blacklist hits of target ip
	wget -q -O $dir/blcheck https://raw.githubusercontent.com/ch604/blcheck/master/blcheck
	ec yellow "Checking target IP against blacklists..."
	bash $dir/blcheck -q $cpanel_main_ip
	local hits=$?
	if [ $hits -gt 0 ]; then
		ec red "$cpanel_main_ip is listed on $hits blacklists! Please investigate further! (cat $dir/blcheck_blacklists.txt)" | errorlogit 2
		mv ~/blcheck_blacklists.txt $dir/
		sed -i '/'$cpanel_main_ip'/d' $dir/blcheck_blacklists.txt
	fi
}
