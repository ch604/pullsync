copybackdns() { #only called during final sync, copy zonefiles of copied domains back to source server
	if [ "$copydns" ]; then
		ec yellow "Backing up /var/named to $remote_tempdir on remote server..."
		sssh "rsync -aqH /var/named $remote_tempdir/ --exclude=data --exclude=chroot"
		ec yellow "Copying zone files back to old server..."
		for domain in $domainlist; do
			if [ -f "/var/named/${domain}.db" ]; then
				sed -i -e 's/^\$TTL.*/$TTL 300/g' -e 's/[0-9]\{10\}/'`date +%Y%m%d%H`'/g' /var/named/$domain.db
				rsync $rsyncargs -e "ssh $sshargs" /var/named/$domain.db $ip:/var/named/
			fi
		done
		sssh "service named restart; rndc reload &> /dev/null; [ -f /var/cpanel/usensd ] && ( nsdc rebuild && nsdc reload ) &> /dev/null; [ -f /var/cpanel/usepowerdns ] && ( pdns_control cycle && pdns_control reload ) &> /dev/null"
		if [ -f $dir/var/cpanel/useclusteringdns ]; then
			ec yellow "Source DNS cluster detected, syncing across all servers..."
			# cpanel must be running on source to run dnscluster
			sssh "[ -f /etc/init.d/cpanel ] && /etc/init.d/cpanel status || service cpanel status" &> /dev/null
			local cpanelup=$?
			[ $cpanelup -ne 0 ] && sssh "[ -f /etc/init.d/cpanel ] && /etc/init.d/cpanel start || service cpanel start" &> /dev/null
			for domain in $domainlist; do
				sssh "/scripts/dnscluster synczone $domain" &> /dev/null
			done
		fi
	fi
}
