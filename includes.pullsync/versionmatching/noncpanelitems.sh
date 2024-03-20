noncpanelitems() { #look for non-cpanel listening services, vhosts, linux users, and zonefiles to warn tech
	ec yellow "Checking for non-cpanel items:"
	a=0; b=0; c=0; d=0; e=0

	#users
	ec yellow " Users..."
	noncpanelusers="$(cat $dir/etc/passwd | cut -d\: -f1 | egrep -v "(^${systemusers}$)" | egrep -v "(^$(echo $(\ls -A $dir/var/cpanel/users/) | tr ' ' '|')$)")"
	for user in $noncpanelusers; do
		if ! grep -q ^$user\: /etc/passwd; then
			let a+=1
			echo $user >> $dir/missinglinuxusers.txt
			grep ^$user\: $dir/etc/passwd >> $dir/missinglinuxusers.txt
			echo "" >> $dir/missinglinuxusers.txt
		fi
	done
	[ $a -ne 0 ] && ec red "$a non-cpanel linux users detected on source!"

	#vhosts
	ec yellow " VirtualHosts..."
	# get a list of vhosts
	sssh "httpd -S &> /dev/null"
	if [ $? -eq 0 ]; then
		for domain in $(sssh "httpd -S 2> /dev/null" | awk '/namevhost/ && !/localhost / {print $4}' | sort -u | egrep -v ${valid_ip_format} | sed -e 's/_wildcard_/\\\*/g'); do
			# print any vhosts that arent set up in userdata
			if ! grep -qRE "\ \"?$domain\"?(:|$)" $dir/var/cpanel/userdata/; then
				let b+=1
				echo $domain >> $dir/missingvhosts.txt
				sssh "httpd -S 2> /dev/null | grep namevhost\ ${domain}" >> $dir/missingvhosts.txt
				echo "" >> $dir/missingvhosts.txt
			fi
		done
		[ $b -ne 0 ] && ec red "$b vhosts on source not in cpanel!"
	else
		ec white "Couldn't execute 'httpd -S' on source, skipping this test."
	fi

	#zonefiles
	ec yellow " DNS records..."
	for domain in $(awk -F\" '/^zone/ && !/\.arpa\"/ {print $2}' $dir/etc/named.conf | sort -u); do
		# print any zone domains that arent set up in userdata
		if ! grep -qRE "\ $domain(:|$)" $dir/var/cpanel/userdata/; then
			let c+=1
			echo $domain >> $dir/missingdnszones.txt
			grep -A3 ^zone\ \"$domain\" $dir/etc/named.conf >> $dir/missingdnszones.txt
			echo "" >> $dir/missingdnszones.txt
		fi
	done
	[ $c -ne 0 ] && ec red "$c zonefiles on source not in cpanel!"

	#enabled services
	ec yellow " Enabled services..."
	# skip core services
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
			let d+=1
			echo $service >> $dir/missingservices.txt
		done
	fi
	[ $d -ne 0 ] && ec red "$d services enabled on source which arent on target!"

	#listening services
	ec yellow " Listening services..."
	# most default listeners are enabled on both, so compare directly and only get differences. exclude mysql and variants because of name changes.
	sssh "netstat -plunt" | awk '{print $7}' | cut -d\/ -f2 | sort -u | grep -v -e ^$ -e ^Address$ -e ^mysql$ -e ^mysqld$ -e ^mariadbd$ -e ^mariadb$ > $dir/remotelistening.txt
	netstat -plunt | awk '{print $7}' | cut -d\/ -f2 | sort -u | grep -v -e ^$ -e ^Address$ -e ^mysql$ -e ^mysqld$ -e ^mariadbd$ -e ^mariadb$ > $dir/locallistening.txt
	if grep -qv -f $dir/locallistening.txt $dir/remotelistening.txt; then
		for service in $(grep -v -f $dir/locallistening.txt $dir/remotelistening.txt); do
			let e+=1
			echo $service >> $dir/missinglisteners.txt
		done
	fi
	[ $e -ne 0 ] && ec red "$e processes listening on source which arent on target!"

	#summary
	if [ $((a+b+c+d+e)) -gt 0 ]; then
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
