copybackdns() { #only called during final sync, copy zonefiles of copied domains back to source server
	if [ "$copydns" ]; then
		ec yellow "Backing up /var/named to $remote_tempdir on remote server..."
		sssh "rsync -aqH /var/named $remote_tempdir/ --exclude=data --exclude=chroot"
		ec yellow "Copying zone files back to old server..."
		# shellcheck disable=SC2086
		parallel -j 100% -u "if [ -f /var/named/{}.db ]; then sed -i -e 's/^\$TTL.*/\$TTL 300/g' -e 's/[0-9]\{10\}/'$(date +%Y%m%d%H)'/g' /var/named/{}.db; srsync /var/named/{}.db $ip:/var/named/; fi" ::: $domainlist
		sssh "service named restart; rndc reload &> /dev/null; [ -f /var/cpanel/usensd ] && ( nsdc rebuild && nsdc reload ) &> /dev/null; [ -f /var/cpanel/usepowerdns ] && ( pdns_control cycle && pdns_control reload ) &> /dev/null"
		if [ -f "$dir/var/cpanel/useclusteringdns" ]; then
			ec yellow "Source DNS cluster detected, syncing across all servers..."
			# cpanel must be running on source to run dnscluster
			! sssh "if which service; then service cpanel status; else /etc/init.d/cpanel status; fi" &> /dev/null && sssh "/scripts/restartsrv_cpsrvd" &> /dev/null
			# shellcheck disable=SC2086
			parallel -j 100% -u 'sssh "/scripts/dnscluster synczone {}" &> /dev/null' ::: $domainlist
		fi
	fi
}
