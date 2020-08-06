hosts_file() { #creates testing info for user $1, also generates line for running marill. progress optionally passed.
	local user=$1
	ec yellow "$progress Generating hosts file entries for $user"
	if [ -f /var/cpanel/users/$user ]; then
		local user_IP=`grep ^IP /var/cpanel/users/$user |cut -d= -f2`
		#check for natted ips
		if [ -f /var/cpanel/cpnat ] && grep -q $user_IP /var/cpanel/cpnat; then
			user_IP=$(grep $user_IP /var/cpanel/cpnat | awk '{print $2}')
		fi
		local user_domains=`grep ^DNS /var/cpanel/users/$user |cut -d= -f2 |grep -v \*`
		#per user way
		echo -n "$user_IP " | tee -a $hostsfile
		echo $user_domains | while read DOMAIN ; do
			echo -n "$DOMAIN www.$DOMAIN "
	  	done | tee -a $hostsfile
	  	echo "" | tee -a $hostsfile
		#one line per domain
		for domain in $user_domains; do
			echo "$user_IP $domain" >> $hostsfile_alt
			echo "$user_IP www.$domain" >> $hostsfile_alt
			echo "${domain}:${user_IP}" >> $dir/marilldomains.txt
		done
	else
		ec lightRed "Cpanel user file for $user not found, not generating hosts file entries!" | errorlogit 3
	fi
}
