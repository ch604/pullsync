lower_ttls() { # should have a domainlist at this point, called from getuserlist() to lower TTLs on source server
	ec yellow "Lowering TTLs for selected users..."
	# back up /var/named on remote server
	sssh "rsync -aqH /var/named $remote_tempdir/ --exclude=data --exclude=chroot"
	# we have /var/named from source server, run our seds locally to make things easier, then copy them back to original server.
	if [ -f $dir/domainlist.txt ]; then
		domainlist=$(cat $dir/domainlist.txt)
		mkdir -p $dir/var/named
		> $dir/rsynczones.txt
		for domain in $domainlist; do
			echo ${domain}.db >> $dir/rsynczones.txt
		done
		# make sure we have all the necessary zonefiles
		rsync --files-from=$dir/rsynczones.txt $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:/var/named/ $dir/var/named/ 2>&1 | stderrlogit 4
		# lower main ttl and update serial number
		for domain in $domainlist; do
			if [ -f $dir/var/named/${domain}.db ]; then
				sed -i -e 's/^\$TTL.*/\$TTL 300/g' $dir/var/named/${domain}.db
				# use whitespace or ; to delimit serial, to avoid editing other random 10 digit strings around the file
				sed -i -e '/(\s|^)[0-9]{10}(\s|$|;)/s/[0-9]{10}/'$(date +%Y%m%d%H)'/g' $dir/var/named/${domain}.db
				# A record reducer
				sed -i -E -e 's/^([^[:blank:]]+[[:blank:]]+)[0-9]+([[:blank:]]+IN[[:blank:]]+A[[:blank:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.*$)/\1300\2/g' $dir/var/named/${domain}.db
			fi
		done
		# copy them back over
		rsync --files-from=$dir/rsynczones.txt $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $dir/var/named/ $ip:/var/named/ 2>&1 | stderrlogit 4
	else
		ec lightRed "Error: Domainlist not found $dir/domainlist.txt!" | errorlogit 2
	fi
	# reload on remote server to lower ttls
	sssh "rndc reload &> /dev/null; [ -f /var/cpanel/usensd ] && ( nsdc rebuild && nsdc reload ) &> /dev/null; [ -f /var/cpanel/usepowerdns ] && ( pdns_control cycle && pdns_control reload ) &> /dev/null"
}
