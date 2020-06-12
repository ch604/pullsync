noncpanelitems() { #look for non-cpanel listening services, vhosts, linux users, and zonefiles to warn tech
	ec yellow "Checking for non-cpanel items:"

	#users
	ec yellow " Users..."
	noncpanelusers="$(cat $dir/etc/passwd | cut -d\: -f1 | egrep -v "(^${systemusers}$)" | egrep -v "(^$(echo $(\ls -A $dir/var/cpanel/users/) | tr ' ' '|')$)")"
	for user in $noncpanelusers; do
		if ! grep -q ^$user\: /etc/passwd; then
			ec red "$user is a non-cpanel linux user on source, but not on target!"
			echo $user >> $dir/missinglinuxusers.txt
			grep ^$user\: $dir/etc/passwd >> $dir/missinglinuxusers.txt
			echo "" >> $dir/missinglinuxusers.txt
		fi
	done

	#vhosts
	ec yellow " VirtualHosts..."
	# get a list of vhosts
	sssh "httpd -S &> /dev/null"
	if [ $? -eq 0 ]; then
		for domain in $(sssh "httpd -S 2> /dev/null" | grep namevhost | awk '{print $4}' | sort -u | egrep -v ${valid_ip_format} | egrep -v localhost$ | sed -e 's/_wildcard_/\\\*/g'); do
			# print any vhosts that arent set up in userdata
			if ! grep -qRE "\ \"?$domain\"?(:|$)" $dir/var/cpanel/userdata/; then
				ec red "$domain is a vhost on source, but is not in cpanel!"
				echo $domain >> $dir/missingvhosts.txt
				sssh "httpd -S 2> /dev/null | grep namevhost\ ${domain}" >> $dir/missingvhosts.txt
				echo "" >> $dir/missingvhosts.txt
			fi
		done
	else
		ec white "Couldn't execute 'httpd -S' on source, skipping this test."
	fi

	#zonefiles
	ec yellow " DNS records..."
	for domain in $(grep ^zone $dir/etc/named.conf | awk -F\" '{print $2}' | grep -v \.arpa$ | sort -u); do
		# print any zone domains that arent set up in userdata
		if ! grep -qRE "\ $domain(:|$)" $dir/var/cpanel/userdata/; then
			ec red "$domain is a zonefile on source, but is not in cpanel!"
			echo $domain >> $dir/missingdnszones.txt
			grep -A3 ^zone\ \"$domain\" $dir/etc/named.conf >> $dir/missingdnszones.txt
			echo "" >> $dir/missingdnszones.txt
		fi
	done

	#enabled services
	ec yellow " Enabled services..."
	# get enabled services with systemctl or chkconfig
	if [ "$(sssh 'which systemctl 2> /dev/null')" ]; then
		sssh "systemctl list-unit-files" | awk '$2 == "enabled" {print $1}' | egrep -v '(target|socket|path)$' | sed -e 's/\.service$//g' | egrep -v "(^${systemservices}$)" > $dir/remoterunlist.txt
	else
		sssh "chkconfig --list" | awk '$5 == "3:on" {print $1}' | egrep -v "(^${systemservices}$)" > $dir/remoterunlist.txt
	fi
	if [ "$(which systemctl 2> /dev/null)" ]; then
		systemctl list-unit-files | awk '$2 == "enabled" {print $1}' | egrep -v '(target|socket|path)$' | sed -e 's/\.service$//g' > $dir/localrunlist.txt
	else
		chkconfig --list | awk '$5 == "3:on" {print $1}' > $dir/localrunlist.txt
	fi
	if grep -qv -f $dir/localrunlist.txt $dir/remoterunlist.txt; then
		# list services not on target
		for service in $(grep -v -f $dir/localrunlist.txt $dir/remoterunlist.txt); do
			ec red "$service is enabled on source, but not on target!"
			echo $service >> $dir/missingservices.txt
		done
	fi

	#listening services
	ec yellow " Listening services..."
	# most default listeners are enabled on both, so compare directly and only get differences
	sssh "netstat -plunt" | awk '{print $7}' | cut -d\/ -f2 | sort -u | grep -v -e ^$ -e ^Address$ > $dir/remotelistening.txt
	netstat -plunt | awk '{print $7}' | cut -d\/ -f2 | sort -u | grep -v -e ^$ -e ^Address$ > $dir/locallistening.txt
	if grep -qv -f $dir/locallistening.txt $dir/remotelistening.txt; then
		for service in $(grep -v -f $dir/locallistening.txt $dir/remotelistening.txt); do
			ec red "$service is listening on source, but not on target!"
			echo $service >> $dir/missinglisteners.txt
		done
	fi

	#summary
	if [ -f $dir/missingdnszones.txt -o -f $dir/missingvhosts.txt -o -f $dir/missinglinuxusers.txt -o -f $dir/missingservices.txt -o -f $dir/missinglisteners.txt ]; then
		ec red "Errors found with non-cpanel items! Please resolve issues listed in these files manually later if needed!" | errorlogit 5
		[ -f $dir/missingdnszones.txt ] && ec white $dir/missingdnszones.txt | errorlogit 5
		[ -f $dir/missingvhosts.txt ] && ec white $dir/missingvhosts.txt | errorlogit 5
		[ -f $dir/missinglinuxusers.txt ] && ec white $dir/missinglinuxusers.txt | errorlogit 5
		[ -f $dir/missingservices.txt ] && ec white $dir/missingservices.txt | errorlogit 5
		[ -f $dir/missinglisteners.txt ] && ec white $dir/missinglisteners.txt | errorlogit 5
		say_ok
	else
		ec green "No discrepancies detected. Weird."
	fi
}
