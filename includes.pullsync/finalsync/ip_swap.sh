ip_swap() { #automatically remove ips from the source server and assign them to the target server, aligning specific cpanel settings. assign the main ip of the target server back to the source server as well.
	ec red "Ready to begin the IP swap! There is no interrupting the task once it begins!"
	ec red "Stopping the task partway through could cause unexpected complications."
	say_ok
	local ethdev=$(awk '/^ETHDEV / {print $2}' $dir/etc/wwwacct.conf)
	[ "${ethdev}" = "" ] && ethdev=eth0
	local localethdev=$(awk '/^ETHDEV / {print $2}' /etc/wwwacct.conf)
	[ "${localethdev}" = "" ] && localethdev=eth0
	local expectedips=$(echo "$(cut -d\: -f1 ${dir}/etc/ips) $(awk -F= '/^IPADDR=/ {print $2}' $dir/etc/sysconfig/network-scripts/ifcfg-${ethdev})" | tr ' ' '\n')
	ec red "Changing IPs on source machine and stopping networking."
	ec lightRed "THE SOURCE SERVER WILL THEN REBOOT AFTER 5 MINUTES."

	#ssh to source, back up remote eth configs, change the ip address, remove extra ips from /etc/ips, and shutdown in 1 minute
	local gateway=$(awk -F= '/^GATEWAY=/ {print $2}' /etc/sysconfig/network-scripts/ifcfg-${localethdev})
	sssh "cp -a /etc/sysconfig/network-scripts/ifcfg-${ethdev} /root/ifcfg-${ethdev}.ipswapbak; sed -i -e '/^GATEWAY/s/^/#/' -e '/^IPADDR/s/^/#/' /etc/sysconfig/network-scripts/ifcfg-${ethdev}; echo IPADDR=$cpanel_main_ip >> /etc/sysconfig/network-scripts/ifcfg-${ethdev}; echo GATEWAY=$gateway >> /etc/sysconfig/network-scripts/ifcfg-${ethdev}; mv /etc/ips{,.ipswapbak}; touch /etc/ips; echo 'service network stop; /etc/init.d/network stop; sleep 300; reboot' | at now"
	sleep 5

	#copy back core cpanel files with the new ips for recreating configs
	ec yellow "Updating configurations to match source IP usage..."
	mv /etc/ips{,.ipswap}
	rsync $rsyncargs --bwlimit=$rsyncspeed $dir/etc/ips /etc/
	mv /var/cpanel/userdata{,.ipswap}
	mv /var/cpanel/users{,.ipswap}
	rsync $rsyncargs --bwlimit=$rsyncspeed $dir/var/cpanel/userdata $dir/var/cpanel/users /var/cpanel/
	sed -i.ipswapbak '/^ADDR\ /s/^/#/' /etc/wwwacct.conf
	local old_cpanel_main_ip=$(awk '/^ADDR [0-9]/ {print $2}' $dir/etc/wwwacct.conf | tr -d '\n')
	echo "ADDR $old_cpanel_main_ip" >> /etc/wwwacct.conf

	#regenerate configs
	ec yellow "Updating user domain configs and setting up SSLs..."
	/usr/local/cpanel/scripts/updateuserdomains
	[ ! -d /usr/share/ssl ] && ln -s /etc/ssl /usr/share/ssl
	[ -d $dir/var/cpanel/ssl/installed ] && [ -d /var/cpanel/ssl/installed ] && rsync $rsyncargs --bwlimit=$rsyncspeed $dir/var/cpanel/ssl/installed/ /var/cpanel/ssl/installed/
	ec yellow "Rebuilding apache config..."
	[ ! -h /usr/local/apache/conf/httpd.conf ] && mv /usr/local/apache/conf/httpd.conf{,.ipswap}
	/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
	ec yellow "Restarting web server daemon..."
	if ps axc | grep -qEe '(litespeed|lsws|lshttpd)'; then
		ec yellow "Litespeed detected"
		service lsws restart
	elif ps axc | grep -qe nginx; then
		ec yellow "Nginx detected"
		if [ -f /engintron.sh ]; then
			ec red "ENGINTRON DETECTED! Make sure the vhosts are set up properly in /etc/nginx/ following the ip swap." | errorlogit 2
			bash /engintron.sh res
		else
			/scripts/restartsrv_httpd
			service nginx restart
		fi
	else
		/scripts/restartsrv_httpd
	fi
	# convert sites back to php-fpm to combat 503 errors
	for dom in $domlist; do
		local user=$(/scripts/whoowns $dom)
		if [ -f /var/cpanel/userdata.ipswap/$user/$dom.php-fpm.yaml ]; then
			local ea4profile=$(awk -F'==' '/^'$dom': / {print $NF}' /etc/userdatadomains)
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$ea4profile php_fpm=1 vhost-0=$dom 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$ea4profile php_fpm=1 vhost-0=$dom 2>&1 | stderrlogit 3
		fi
	done
	if ps axc | grep -qe php-fpm; then
		/scripts/restartsrv_apache_php_fpm
	fi
	ec yellow "Copying original DNS into /var/named..."
	mv /var/named{,.ipswap}
	mv /etc/named.conf{,.ipswap}
	mv /etc/localdomains{,.ipswap}
	mv /etc/remotedomains{,.ipswap}
	rsync $rsyncargs --bwlimit=$rsyncspeed $dir/var/named /var/
	rsync $rsyncargs --bwlimit=$rsyncspeed $dir/etc/localdomains $dir/etc/remotedomains /etc/
	sed -i.lwbak -e 's/^\$TTL.*/$TTL 300/g' -e 's/[0-9]\{10\}/'$(date +%Y%m%d%H)'/g' /var/named/*.db
	/scripts/rebuilddnsconfig
	rndc reload 2>&1 | stderrlogit 4
	[ -f /var/cpanel/usensd ] && ( nsdc rebuild && nsdc reload ) 2>&1 | stderrlogit 4
	[ -f /var/cpanel/usepowerdns ] && ( pdns_control cycle && pdns_control reload ) 2>&1 | stderrlogit 4

	#get ready to change the eth configs on target server
	ec red "About to update the IP configuration of the server! You will probably be disconnected from the machine! After you hit enter, disconnect from your screen session, clear ARP for the main shared IP at https://noc.liquidweb.com/core/arpmac/, and ssh back to the new IP, $old_cpanel_main_ip. The script will wait for your return before proceeding. This should take about 30 seconds."
	say_ok
	sleep 5
	ec red "Updating the main IP of the server..."
	mkdir /root/ipswap-ethconfigs/
	mv /etc/sysconfig/network-scripts/ifcfg-${localethdev} /root/ipswap-ethconfigs/
	mv /etc/sysconfig/network-scripts/ifcfg-eno* /root/ipswap-ethconfigs/ #remove ipv6 items
	cp $dir/etc/sysconfig/network-scripts/ifcfg-${ethdev} /etc/sysconfig/network-scripts/ifcfg-${localethdev}
	sed -i -e 's/^HWADDR/#HWADDR/g' -e "3iHWADDR=$(cat /sys/class/net/${localethdev}/address)" -e 's/'${ethdev}'/'${localethdev}'/g' /etc/sysconfig/network-scripts/ifcfg-${localethdev}

	#kick out users by killing sshd, enforce the new network configs by restarting networking, ipaliases, and sshd.
	ec red "Restarting networking..."
	(killall sshd; service network stop; service network start; /scripts/restartsrv_ipaliases; /scripts/restartsrv_sshd)
	ec green "Done!"
	ec yellow "Attempting to clear arp automatically..."
	local newips=$(echo "$(cut -d\: -f1 /etc/ips) $(awk -F= '/^IPADDR=/ {print $2}' /etc/sysconfig/network-scripts/ifcfg-${localethdev})" | tr ' ' '\n')
	for each in $newips; do
		ec white " $each"
		arping -q -c2 -I $localethdev $each
	done
	if [ ! "$(echo "${expectedips}" | sort)" = "$(echo "${newips}" | sort)" ]; then
		ec red "WARNING! I don't see all of the IPs I'm expecting!"
		ec lightRed "Here are the IPs I found on the old server:"
		echo "$expectedips" | sort | logit
		ec lightRed "Here are the IPs I detected on the new server after the swap:"
		echo "$newips" | sort | logit
		ec red "You will have to fix this yourself! SORRY!"
		say_ok
	else
		ec green "I found all the IPs I expected."
	fi
	ec yellow "While the script proceeds, please also clear ARP for these IPs:"
	cut -d\: -f1 /etc/ips
	say_ok

	#post ipswap scripts to get everything lined up nice
	ec yellow "Updating cpanel key and pushing a UPCP to the background..."
	/usr/local/cpanel/cpkeyclt
	/scripts/restartsrv_named
	/usr/local/cpanel/bin/checkallsslcerts
	screen -S upcp -d -m /scripts/upcp
	rpm -q --quiet yumconf-serversecureplus && slackhook_secteam
}
