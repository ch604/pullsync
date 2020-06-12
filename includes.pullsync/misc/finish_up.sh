finish_up() { #run after every clean exit through main(), performs tidying up functions and ensures certain items are set up
	ec yellow "Fixing mail permissions..."
	screen -S mailperm -d -m /scripts/mailperm
	ec yellow "Fixing cpanel quotas..."
	screen -S fixquotas -d -m /scripts/fixquotas
	ec yellow "Fixing monitoring..."
	/usr/local/cpanel/bin/whmapi1 enable_monitor_all_enabled_services 2>&1 | stderrlogit 3
	ec yellow "Ensuring LW CSF rules installed..."
	screen -S lwcsf -d -m yum -y install lw-csf-rules lw-hosts-access
	ec yellow "Setting up A record for hostname..."
	#reset the cpanel_main_ip variable if there was an ip swap
	[ "$ipswap" ] && cpanel_main_ip=`grep "^ADDR\ [0-9]" /etc/wwwacct.conf | awk '{print $2}' | tr -d '\n'`
	[ "$cpanel_main_ip" = "" ] && cpanel_main_ip=`cat /var/cpanel/mainip`
	adjust_dns_record $(hostname) $cpanel_main_ip
	if [ ! -f /var/cpanel/useclusteringdns ] && [ ! -d /var/cpanel/cluster/root/config/ ]; then #no clustering only
		ec yellow "Setting up A records for nameservers..."
		local nscount=1
		for ns in $(/usr/local/cpanel/bin/whmapi1 get_nameserver_config | grep \ -\  | awk '{print $2}'); do
			if [ -s /etc/ips ] && [ $nscount -ne 1 ]; then
				local newip=$(cat /etc/ips | grep -v ^$ | head -n$(($nscount - 1)) | tail -n1 | cut -d: -f1)
			else
				local newip=$cpanel_main_ip
			fi
			adjust_dns_record $ns $newip
			nscount=$(($nscount + 1))
		done
	fi
	ec yellow "Fixing cPanel RPMs..."
	screen -S cpanelrpms -d -m /usr/local/cpanel/scripts/check_cpanel_rpms --fix
	ec yellow "Adding SPF/DKIM..."
	screen -S dkimspf -d -m bash -c "for each in $userlist; do /usr/local/cpanel/bin/dkim_keys_install \$each; /usr/local/cpanel/bin/spf_installer \$each; done"
	ec yellow "Intiating check in the background for signed hostname cert..."
	nohup sh -c 'sleep 200 && /usr/local/cpanel/bin/checkallsslcerts --allow-retry --verbose' &> /dev/null &
}
