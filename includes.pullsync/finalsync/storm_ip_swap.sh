storm_ip_swap() {
	ec red "Ready to begin the Storm IP migration! A cron will be made for post-reboot on this server."
	ec red "Once the script exits, log into billing and perform the provisioning ip swap between the source and target storm servers."
	say_ok

	#create target reboot cron
	cat > /etc/cron.d/pullsync-postipswap << EOF
@reboot sleep 30; mv /var/cpanel/userdata{,.ipswap}; mv /var/cpanel/users{,.ipswap}; rsync -aq $dir/var/cpanel/userdata $dir/var/cpanel/users /var/cpanel/; sed -i.ipswapbak '/^ADDR\ /s/^/#/' /etc/wwwacct.conf; echo "ADDR $(awk '/^ADDR [0-9]/ {print $2}' $dir/etc/wwwacct.conf | tr -d '\n')" >> /etc/wwwacct.conf; /usr/local/cpanel/scripts/updateuserdomains; /scripts/rebuildhttpdconf; /scripts/restartsrv_httpd; mv /var/named{,.ipswap};mv /etc/named.conf{,.ipswap}; mv /etc/localdomains{,.ipswap}; mv /etc/remotedomains{,.ipswap}; rsync -aq $dir/var/named /var/; rsync -aq $dir/etc/localdomains $dir/etc/remotedomains /etc/; /scripts/rebuilddnsconfig; rndc reload; /scripts/restartsrv_named; /usr/local/cpanel/cpkeyclt; /usr/local/cpanel/bin/whmapi1 start_autossl_check_for_all_users; screen -S upcp -d -m /scripts/upcp; rm -f /etc/cron.d/pullsync-postipswap
EOF
}
