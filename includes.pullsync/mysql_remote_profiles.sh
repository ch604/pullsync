mysql_remote_profiles() { #check for remote profiles on both servers
	if [ -f "$dir/var/cpanel/mysql_status" ] && grep -q "remote=1" "$dir/var/cpanel/mysql_status"; then
		ec red "Source server has remote mysql server. This is normally not a problem, just wanted to let you know."
		sourceremotemysql=1
	fi
	# do the same on target server
	if [ -f /var/cpanel/mysql_status ] && grep -q "remote=1" /var/cpanel/mysql_status; then
		ec red "Target server has remote mysql server. This is normally not a problem, just wanted to let you know."
		targetremotemysql=1
		if [ ! -s /var/cpanel/mysqlaccesshosts ]; then
			ec lightRed "Target server does not have any mysql access hosts set up!"
			if yesNo "Do you want me to do that for you?"; then
				for i in $(whmapi1 listips --output=json | jq -r '.data.ip[].ip') $(hostname) $(hostname | cut -d. -f1); do
					echo "$ip" >> /var/cpanel/mysqlaccesshosts
				done
				if whmapi1 listips | grep -q \ 192.168; then
					echo "192.168.%" >> /var/cpanel/mysqlaccesshosts
				fi
				if whmapi1 listips | grep -q \ 172.16; then
					echo "172.16.%" >> /var/cpanel/mysqlaccesshosts
				fi
			else
				ec Red "Suit yourself!"
				ec Red "Dont forget to set up mysql access hosts and make sure grants are working!" | errorlogit 3 root
			fi
		fi
	fi
	# throw a big flag if both servers have remote mysql
	if [ "$sourceremotemysql" ] && [ "$targetremotemysql" ]; then
		ec lightRed "I think that both servers are using remote mysql. If they are using the SAME remote mysql host, THIS IS A BIG PROBLEM. STOP HERE AND INVESTIGATE."
		say_ok
	fi
}
