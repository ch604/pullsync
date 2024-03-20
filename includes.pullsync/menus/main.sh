main() { #the main menu dialog box and case statement. passes sync commands to synctype_logic() and describes the function lists of other commands.
	# store variables for the menu
	# old menu title: local cmd=(dialog --colors --nocancel --backtitle "pullsync" --title "Main Menu" --radiolist "  _____________  ______________________  ______   __________   ______\n  ___  __ \_  / / /__  /___  /__  ___/ \/ /__  | / /_  ____/   /__  /\n  __  /_/ /  / / /__  / __  / _____ \__  /__   |/ /_  /        __  / \n  _  ____// /_/ / _  /___  /______/ /_  / _  /|  / / /___      _  /  \n  /_/     \____/  /_____/_____/____/ /_/  /_/ |_/  \____/      /_/   \n\n$scriptname\nversion: $version\nStarted at $starttime\n\nGreetings, $sshClientIP. Choose your Destiny:" 0 0 26)
	local cmd=(dialog --colors --nocancel --backtitle "pullsync" --title "Main Menu" --radiolist " ██▓███   █    ██  ██▓     ██▓      ██████▓██   ██▓ ███▄    █  ▄████▄     \n▓██░  ██▒ ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▒██  ██▒ ██ ▀█   █ ▒██▀ ▀█     \n▓██░ ██▓▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄    ▒██ ██░▓██  ▀█ ██▒▒▓█    ▄    \n▒██▄█▓▒ ▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒ ░ ▐██▓░▓██▒  ▐▌██▒▒▓▓▄ ▄██▒   \n▒██▒ ░  ░▒▒█████▓ ░██████▒░██████▒▒██████▒▒ ░ ██▒▓░▒██░   ▓██░▒ ▓███▀ ░   \n▒▓▒░ ░  ░░▒▓▒ ▒ ▒ ░ ▒░▓  ░░ ▒░▓  ░▒ ▒▓▒ ▒ ░  ██▒▒▒ ░ ▒░   ▒ ▒ ░ ░▒ ▒  ░   \n░▒ ░     ░░▒░ ░ ░ ░ ░ ▒  ░░ ░ ▒  ░░ ░▒  ░ ░▓██ ░▒░ ░ ░░   ░ ▒░  ░  ▒      \n░░        ░░░ ░ ░   ░ ░     ░ ░   ░  ░  ░  ▒ ▒ ░░     ░   ░ ░ ░           \n            ░         ░  ░    ░  ░      ░  ░ ░              ░ ░ ░         \n                                           ░ ░                ░           \n$scriptname version: $version\nStarted at $starttime\n\nGreetings, $sshClientIP. Choose your Destiny:" 0 0 26)
	local options=(1 "Initial - Single cpanel account" off
	2 "Initial - List of cpanel users from /root/userlist.txt" off
	3 "Initial - List of domains from /root/domainlist.txt" off
	4 "Initial - All users" ON
	5 "Initial - JUST SKELETONS from /root/userlist.txt" off
	8 "Pre-Final Runthrough" off
	9 "Final Sync" off
	a "Update - Full update sync" off
	b "Update - Homedir Sync only" off
	c "Update - Mysql Sync only" off
	d "Update - Pgsql Sync only" off
	ma "Update - Email Sync only (all users)" off
	ml "Update - Email sync only (from ~/userlist.txt)" off
	e "Version Matching only" off
	f "NoOp - Regenerate hostsfile.txt" off
	g "NoOp - Run marill" off
	h "NoOp - Check DNS" off
	i "Cleanup - Remove HostsCheck.php files" off
	j "Cleanup - Cleanup all pullsync data on this machine (including this script)" off
	k "Server state summary (dns+oldmigrations)" off
	wl "NoOp - Run WPT (BETA)" off
	wr "NoOp - Run WPT remote (BETA)" off
	wc "NoOp - Run WPT compare (BETA)" off
	sl "NoOp - Run ab (BETA)" off
	sr "NoOp - Run ab remote (BETA)" off
	0 "quit" off)
	# exectute the menu and store the result
	local choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	# log the choice and its next element
	echo $choice >> $log
	print_next_element options $choice >> $log
	# empty your mind
	clear
	# determine what to do next
	case $choice in
		1)	synctype="single"
			synctype_logic;;
		2)	synctype="list"
			synctype_logic;;
		3)	synctype="domainlist"
			synctype_logic;;
		4)	synctype="all"
			synctype_logic;;
		5)	synctype="skeletons"
			synctype_logic;;
		8)	synctype="prefinal"
			synctype_logic;;
		9)	synctype="final"
			synctype_logic;;
		a)	synctype="update"
			synctype_logic;;
		b)	synctype="homedir"
			synctype_logic;;
		c)	synctype="mysql"
			synctype_logic;;
		d)	synctype="pgsql"
			synctype_logic;;
		e)	synctype="versionmatching"
			synctype_logic;;
		f)	useallusers
			cpnat_check
			if yesNo "Do you want me to remove references to 'final sync' in the reply?"; then
				remove_final_sync_message=1
			fi
			getlocaldomainlist
			> $hostsfile_alt
			for user in $userlist; do
				hosts_file $user
			done
			hostsfile_gen
			exitcleanup 400;;
		g)	runmarill=1
			download_marill
			useallusers
			getlocaldomainlist
			> $hostsfile_alt
			for user in $userlist; do
				hosts_file $user &> /dev/null
			done
			marill_gen
			exitcleanup 401;;
		h)	useallusers
			getlocaldomainlist
			cpnat_check
			dnscheck
			exitcleanup 402;;
		i)	remove_HostsCheck;;
		j)	uninstall;;
		k)	userlist=`/bin/ls -A /var/cpanel/users | egrep -v "^HASH" | egrep -vx "${badusers}"`
			getlocaldomainlist
			cpnat_check
			dnscheck
			(echo "server $cpanel_main_ip current state:"
			echo "current users ($(echo $userlist | wc -w)): $(echo $userlist)"
			echo "current dns:"
			cat $dir/dns.txt
			echo ""
			) > $dir/summary.txt
			summarize
			exitcleanup 403;;
		wl)	ec red "BETA FUNCTION! Don't run in production migrations unless you know whats up!"
			say_ok
			useallusers
			getlocaldomainlist
			> $hostsfile_alt
			for user in $userlist; do
				hosts_file $user &> /dev/null
			done
			mkdir $dir/wptresults
			wpt_localwrapper
			exitcleanup 405;;
		wr)	ec red "BETA FUNCTION! Don't run in production migrations unless you know whats up!"
			say_ok
			useallusers
			getlocaldomainlist
			mkdir $dir/wptresults
			wpt_remotewrapper
			exitcleanup 405;;
		wc)	ec red "BETA FUNCTION! Don't run in production migrations unless you know whats up!"
			say_ok
                        useallusers
                        getlocaldomainlist
			> $hostsfile_alt
			for user in $userlist; do
				hosts_file $user &> /dev/null
			done
			mkdir $dir/wptresults
			wpt_compare
			exitcleanup 405;;
		ma)	synctype="email"
			synctype_logic;;
		ml)	synctype="emaillist"
			synctype_logic;;
		sl)	ec red "BETA FUNCTION! Don't run in production migrations unless you know whats up! THIS CAN DOS A SERVER EZ."
			ec yellow "Hey I'm gonna dos your server now. I'll run 5 concurrent connections for 10 seconds per domain, all against the local ip. This is gonna be problematic if the target is already hosting sites."
			useallusers
			getlocaldomainlist
			yum -y -q install ea-apache24-tools 2>&1 | stderrlogit 4
			> $hostsfile_alt
			for user in $userlist; do
				hosts_file $user &> /dev/null
			done
			if yesNo "Are you sure you want to continue? DID YOU HEAR ME SAY DOS?"; then
				ab_test_localwrapper
			fi
			exitcleanup 406;;
		sr)	ec red "BETA FUNCTION! Don't run in production migrations unless you know whats up! THIS CAN DOS A SERVER EZ."
			exitcleanup 406
			ec yellow "Hey I'm gonna dos your source server now. I'll run 5 concurrent connections for 10 seconds per domain, ALL AGAINST LIVE DNS. YOU MIGHT MESS UP SOMEONES DAY REAL BAD IF YOU DO A LOT OF DOMAINS."
			useallusers
			getlocaldomainlist
			yum -y -q install ea-apache24-tools 2>&1 | stderrlogit 4
			if yesNo "Are you sure you want to continue? DID YOU HEAR ME SAY DOS?"; then
				ab_test_remotewrapper
			fi
			exitcleanup 406;;
		0)	echo "Bye..."
			exitcleanup 99;;
		*)	ec lightRed "How did you get here? Ensure 'dialog' has been installed with yum, or try using a larger terminal window."; exitcleanup 99;;
	esac
	# after you did whatever you did, clean up variables and temp files
	exitcleanup
}
