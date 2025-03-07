ip_swap() { #automatically remove ips from the source server and assign them to the target server, aligning specific cpanel settings. assign the main ip of the target server back to the source server as well.
	local expectedips userip origwwwacct old_cpanel_main_ip newips
	ec red "Ready to begin the IP swap! There is no interrupting the task once it begins!"
	ec red "Stopping the task partway through could cause unexpected complications."
	say_ok

 	expectedips=$(echo "$(cut -d: -f1 ${dir}/etc/ips) $(awk -F= '/^IPADDR=/ {print $2}' $dir/etc/sysconfig/network-scripts/ifcfg-${sourceethdev} 2> /dev/null) $(awk -F= '/^address1/ {print $2}' $dir/etc/NetworkManager/system-connections/${sourceethdev}.nmconnection 2> /dev/null | cut -d\/ -f1)" | tr ' ' '\n' | grep -v ^$)
	ec red "Changing IPs on source machine and stopping networking."
	ec lightRed "THE SOURCE SERVER WILL THEN REBOOT AFTER 5 MINUTES."

	#ssh to source, back up remote eth configs, change the ip address, remove extra ips from /etc/ips, and shutdown in 1 minute
	if [ "$(sssh "rpm --eval %rhel")" -ge 9 ]; then
		sssh "file=/etc/NetworkManager/system-connections/${sourceethdev}.nmconnection; cp -a \$file /root/${sourceethdev}.nmconnection.ipswapbak; sed -i -e '/^address1/s/^/#/' -e '/\[ipv4\]/a address1=${cpanel_main_ip}/${targetcidr},${targetgw}' \$file; mv /etc/ips{,.ipswapbak}; touch /etc/ips; echo 'service NetworkManager stop; sleep 300; reboot' | at now"
	else
		sssh "file=/etc/sysconfig/network-scripts/ifcfg-${sourceethdev}; cp -a \$file /root/ifcfg-${sourceethdev}.ipswapbak; sed -i -e '/^GATEWAY/s/^/#/' -e '/^IPADDR/s/^/#/' \$file; echo IPADDR=$cpanel_main_ip >> \$file; echo GATEWAY=${sourcegw} >> \$file; mv /etc/ips{,.ipswapbak}; touch /etc/ips; echo 'service network stop; /etc/init.d/network stop; sleep 300; reboot' | at now"
	fi
	sleep 5

	#copy back core cpanel files with the new ips for recreating configs
	ec yellow "Updating configurations to match source IP usage..."
	mv /etc/ips{,.ipswap}
	rsync $rsyncargs $dir/etc/ips /etc/
	sed -i.ipswapbak '/^ADDR\ /s/^/#/' /etc/wwwacct.conf
	old_cpanel_main_ip=$(awk '/^ADDR [0-9]/ {print $2}' $dir/etc/wwwacct.conf | tr -d '\n')
	echo "ADDR $old_cpanel_main_ip" >> /etc/wwwacct.conf

	#clear some cache files out of the way so that whm will rebuild and show the right data
	mv /var/cpanel/users.cache{,.ipswap}
	mv /var/cpanel/globalcache/cpanel.cache{,.ipswap}
	mv /var/cpanel/conf/apache/primary_virtual_hosts.conf{,.ipswap}
	rsync $rsyncargs $dir/var/cpanel/conf/apache/primary_virtual_hosts.conf /var/cpanel/conf/apache/

	#get ready to change the eth configs on target server
	ec red "About to update the IP configuration of the server! You will probably be disconnected from the machine!"
	ec white "After you hit enter, disconnect from your screen session, clear ARP for the main shared IP, and ssh back to the new IP, $old_cpanel_main_ip. The script will wait for your return before proceeding. This should take about 30 seconds."
	ec red "Updating the main IP of the server..."
	mkdir /root/ipswap-ethconfigs/
	if [ "$(rpm --eval %rhel)" -ge 9 ]; then
		cp -a /etc/NetworkManager/system-connections/${targetethdev}.nmconnection /root/ipswap-ethconfigs/
		sed -i -e '/^address1/s/^/#/' -e '/\[ipv4\]/a address1='${old_cpanel_main_ip}'/'${sourcecidr}','${sourcegw} /etc/NetworkManager/system-connections/${targetethdev}.nmconnection
	else
		mv /etc/sysconfig/network-scripts/ifcfg-${targetethdev} /root/ipswap-ethconfigs/
		cp $dir/etc/sysconfig/network-scripts/ifcfg-${sourceethdev} /etc/sysconfig/network-scripts/ifcfg-${targetethdev}
		sed -i -e 's/^HWADDR/#HWADDR/g' -e "3iHWADDR=$(cat /sys/class/net/${targetethdev}/address)" -e 's/'${sourceethdev}'/'${targetethdev}'/g' /etc/sysconfig/network-scripts/ifcfg-${targetethdev}
	fi
	ec white "Please take a moment to confirm the ethernet config is as expected for this machine, and then press enter to continue."
	[ -f /etc/NetworkManager/system-connections/${targetethdev}.nmconnection ] && cat /etc/NetworkManager/system-connections/${targetethdev}.nmconnection
	[ -f /etc/sysconfig/network-scripts/ifcfg-${targetethdev} ] && cat /etc/sysconfig/network-scripts/ifcfg-${targetethdev}
	ec red "If there are any issues, please resolve this now before pressing enter, as I will kick you out and restart networking immediately after."
	sleep 5
	say_ok

	#kick out users by killing sshd, enforce the new network configs by restarting networking, ipaliases, cpipv6, and sshd.
	ec red "Restarting networking..."
	if [ "$(rpm --eval %rhel)" -ge 9 ]; then
		(killall sshd; service NetworkManager stop; service NetworkManager start; /scripts/restartsrv_ipaliases; /scripts/restartsrv_cpipv6; /scripts/restartsrv_sshd)
	else
		(killall sshd; service network stop; service network start; /scripts/restartsrv_ipaliases; /scripts/restartsrv_cpipv6; /scripts/restartsrv_sshd)
	fi
	ec green "Done!"
	ec yellow "Attempting to clear arp automatically..."
	newips=$(echo "$(cut -d: -f1 /etc/ips) $(awk -F= '/^IPADDR=/ {print $2}' /etc/sysconfig/network-scripts/ifcfg-${targetethdev} 2> /dev/null) $(awk -F= '/^address1/ {print $2}' /etc/NetworkManager/system-connections/${targetethdev}.nmconnection 2> /dev/null | cut -d/ -f1)" | tr ' ' '\n' | grep -v ^$)
	for each in $newips; do
		ec white " $each"
		arping -q -c2 -I $targetethdev $each
	done
	if [ ! "$(echo "${expectedips}" | sort -u)" = "$(echo "${newips}" | sort -u)" ]; then
		ec red "WARNING! I don't see all of the IPs I'm expecting!" | errorlogit 1 root
		ec lightRed "Here are the IPs I found on the old server:"
		echo "$expectedips" | sort -u | logit
		ec lightRed "Here are the IPs I detected on the new server after the swap:"
		echo "$newips" | sort -u | logit
		ec red "You will have to fix this yourself! SORRY!" | errorlogit 1 root
		#continue anyway at this point, since if any given IP is not present on the target server, the setsiteip will simply not work
	else
		ec green "I found all the IPs I expected."
	fi

	#loop to adjust user ips
	ec yellow "Adjusting user IPs..."
	origwwwacct=$(mktemp)
	cat /etc/wwwacct.conf >> "$origwwwacct"
	for user in $userlist; do
		userip=$(awk -F= '/^IP=/ {print $2}' "$dir/var/cpanel/users/$user")
		sed -i '/^ADDR\ /d' /etc/wwwacct.conf
		echo "ADDR $userip" >> /etc/wwwacct.conf
		/usr/local/cpanel/bin/whmapi1 setsiteip ip="$userip" user="$user" | stderrlogit 4
	done
	cat "$origwwwacct" > /etc/wwwacct.conf
	rm -f "$origwwwacct"

	ec yellow "Copying original DNS into /var/named..."
	mv /var/named{,.ipswap}
	mv /etc/named.conf{,.ipswap}
	mv /etc/localdomains{,.ipswap}
	mv /etc/remotedomains{,.ipswap}
	rsync $rsyncargs $dir/var/named /var/
	rsync $rsyncargs $dir/etc/localdomains $dir/etc/remotedomains /etc/
	sed -i -e 's/^\$TTL.*/$TTL 300/g' -e 's/[0-9]\{10\}/'"$(date +%Y%m%d%H)"'/g' /var/named/*.db
	/scripts/rebuilddnsconfig
	rndc reload 2>&1 | stderrlogit 4
	[ -f /var/cpanel/usensd ] && ( nsdc rebuild && nsdc reload ) 2>&1 | stderrlogit 4
	[ -f /var/cpanel/usepowerdns ] && ( pdns_control cycle && pdns_control reload ) 2>&1 | stderrlogit 4

	#post ipswap scripts to get everything lined up nice
	ec yellow "Updating cpanel key and pushing a UPCP to the background..."
	/usr/local/cpanel/cpkeyclt
	/scripts/restartsrv_named
	/usr/local/cpanel/bin/checkallsslcerts
	screen -S upcp -d -m /scripts/upcp
}
