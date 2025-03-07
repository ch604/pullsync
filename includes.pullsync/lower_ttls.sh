lower_ttls() { # should have a domainlist at this point, called from getuserlist() to lower TTLs on source server
	ec yellow "Lowering TTLs for selected users..."
	# back up /var/named on remote server
	sssh "rsync -aqH /var/named $remote_tempdir/ --exclude=data --exclude=chroot"
	# we have /var/named from source server, run our seds locally to make things easier, then copy them back to original server.
	if [ "$domainlist" ]; then
		# lower main ttl and update serial number
		# shellcheck disable=SC2086
		parallel -j 100% -u -I ,, -q sssh "[ -f /var/named/,,.db ] && sed -i -E -e 's/^\\\$TTL.*/\\\$TTL 300/' -e '/(\s|^)[0-9]{10}(\s|$|;)/ s/[0-9]{10}/'$(date +%Y%m%d%H)'/g' -e 's/^([^[:blank:]]+[[:blank:]]+)[0-9]+([[:blank:]]+IN[[:blank:]]+A[[:blank:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.*$)/\1300\2/g' /var/named/,,.db" ::: $domainlist
	else
		ec lightRed "Domainlist not set!" | errorlogit 2 root
	fi
	# reload on remote server to lower ttls
	sssh "rndc reload &> /dev/null; [ -f /var/cpanel/usensd ] && ( nsdc rebuild && nsdc reload ) &> /dev/null; [ -f /var/cpanel/usepowerdns ] && ( pdns_control cycle && pdns_control reload ) &> /dev/null"
}
