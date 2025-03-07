hosts_file() { #creates testing info for user $1, also generates line for running marill. progress optionally passed.
	local user=$1
	ec yellow "$progress Generating hosts file entries for $user"
	if [ -f /var/cpanel/users/$user ]; then
		local user_IP=$(grep ^IP /var/cpanel/users/$user | cut -d= -f2)
		#check for natted ips
		if [ -f /var/cpanel/cpnat ] && grep -Eq ^$user_IP\ [0-9]+ /var/cpanel/cpnat; then
			user_IP=$(awk '/^'$user_IP' [0-9]+/ {print $2}' /var/cpanel/cpnat)
		fi
		local user_domains=$(grep ^DNS /var/cpanel/users/$user | cut -d= -f2 | grep -v \*)
		#per user way
		echo -n "$user_IP " | tee -a $hostsfile
		echo $user_domains | while read DOMAIN ; do
			echo -n "$DOMAIN www.$DOMAIN "
	  	done | tee -a $hostsfile
	  	echo "" | tee -a $hostsfile
		#one line per domain
		for domain in $user_domains; do
			echo "$user_IP $domain www.$domain" >> $hostsfile_alt
			echo "${domain}:${user_IP}" >> $dir/marilldomains.txt
		done
		if [ $initsyncwpt ]; then #this is included here because hosts_file already collects the necessary ips and domains
			ec brown "$progress Comparing performance of target domains to source..."
			for domain in $user_domains; do
				wpt_speedtest $domain $user_IP
				wpt_speedtest $domain
			done
		fi
	else
		ec lightRed "Cpanel user file for $user not found, not generating hosts file entries!" | errorlogit 3
	fi
}
