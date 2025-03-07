ipswapcheck() { #logic check and query tech as to whether an ip swap should be performed, called during finalsync_main()
	local remotecount localcount
	remotecount=$(wc -w <<< "$userlist")
	localcount=$(find /var/cpanel/users/ -maxdepth 1 -type f -printf "%f\n" | grep -Ev "^HASH" | grep -cEvx "${badusers}")

	# make sure that source and target are either both nat or both non-nat (TODO doesnt make sure that the prefixes match)
	if (grep -qE "^($natprefix)" <<< "$cpanel_main_ip" && grep -qvE "^($natprefix)" <<< "$ip") || (grep -qE "^($natprefix)" <<< "$ip" && grep -qvE "^($natprefix)" <<< "$cpanel_main_ip"); then
		ec yellow "One server has natted IPs, and the other does not ($ip, $cpanel_main_ip). Skipping IP swap logic."
		unset ipswap
	elif yesNo "Is this an IP swap final sync?"; then
		ipswap=1
		[[ -z "$STY" && -z "$TMUX" ]] && ec red "You do not seem to be in a screen session! The IP swap will destroy the running script when the networking changes! I'm exiting now, please restart the script in a screen." | errorlogit 1 root && exitcleanup 80
		[ "$remotecount" -ne "$localcount" ] && ec red "Userlist count is DIFFERENT between both servers (counted $remotecount and $localcount)! ABORT!" | errorlogit 1 root && exitcleanup 50
		! [[ -d $dir/var/cpanel/userdata && -d $dir/var/cpanel/users && -f $dir/etc/named.conf && -d $dir/var/named && -d $dir/etc/sysconfig/network-scripts ]] && ec red "Unable to find all the files I need in $dir! I'm outta here!" | errorlogit 1 root && exitcleanup 50

		# set variables for later use in the ip_swap() subroutine, to make sure that we can indeed set them
		sourceethdev=$(sssh "route -n" | sort -k5 | awk '/^0.0.0.0/ {print $NF}' | head -1)
		targetethdev=$(route -n | sort -k5 | awk '/^0.0.0.0/ {print $NF}' | head -1)
		sourcegw=$(sssh "route -n" | awk '/^0.0.0.0/ {print $2}')
		targetgw=$(route -n | awk '/^0.0.0.0/ {print $2}')
		if sssh "which ip &> /dev/null"; then
			sssh "ip a s dev $sourceethdev" | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v 127.0.0.1 >> "$dir/ips.txt"
			sourcecidr=$(sssh "ip a s dev $sourceethdev" | awk '/inet / {print $2}' | grep -v 127.0.0.1 | cut -d/ -f2)
		else
			#loop ifconfig for secondary addresses
			sssh "for each in \$(ifconfig | grep ^$sourceethdev | awk '{print \$1}'); do ifconfig \$each | grep inet\ ; done" | awk '{print $2}' | cut -d: -f2 | grep -v 127.0.0.1 >> "$dir/ips.txt"
			sourcecidr=$(ipcalc -p --no-decorate "$ip" "$(sssh "ifconfig $sourceethdev" | awk '/inet / {print $4}')" 2> /dev/null)
		fi
		targetcidr=$(ip a s dev "$targetethdev" | awk '/inet / {print $2}' | grep -v 127.0.0.1 | cut -d/ -f2)

		# if any settings cant be set, abort
		for setting in sourceethdev targetethdev sourcegw targetgw sourcecidr targetcidr; do
			[ ! "${!setting}" ] && ec red "$setting is not set properly! I need to abort the final sync!" | errorlogit 1 root && exitcleanup 50
		done
		[ ! -s "$dir/ips.txt" ] && ec red "Unable to collect list of IPs from source server! Is the program 'ip' or 'ifconfig' available there?" | errorlogit 1 root && exitcleanup 50

		# make sure we have ethdev files
		if [ "$(sssh "rpm --eval %rhel")" -ge 9 ]; then
			[ ! -f "$dir/etc/NetworkManager/system-connections/$sourceethdev.nmconnection" ] && ec red "Source NetworkManager file for $sourceethdev missing!? Aborting" | errorlogit 1 root && exitcleanup 50
			! grep -q "^address1=" "$dir/etc/NetworkManager/system-connections/$sourceethdev.nmconnection" && ec red "Source NetworkManager file for $sourceethdev does not have an address1 line!? Aborting" | errorlogit 1 root && exitcleanup 50
		else
			[ ! -f "$dir/etc/sysconfig/network-scripts/ifcfg-$sourceethdev" ] && ec red "Source ifcfg file for $sourceethdev missing!? Aborting" | errorlogit 1 root && exitcleanup 50
			! grep -q "^IPADDR=" "$dir/etc/sysconfig/network-scripts/ifcfg-$sourceethdev" && ec red "Source ifcfg file for $sourceethdev does not have an IPADDR line!? Aborting" | errorlogit 1 root && exitcleanup 50
		fi
		ec yellow "The following IPs will be added to the target server on $targetethdev following the sync:"
		logit < "$dir/ips.txt"
		ec yellow "Similarly, this IP will be added to the source server on $sourceethdev:"
		echo "$cpanel_main_ip" | logit
		if sssh "/usr/local/cpanel/bin/whmapi1 ipv6_range_list" | grep -q CIDR || /usr/local/cpanel/bin/whmapi1 ipv6_range_list | grep -q CIDR; then
			ec red "One or both servers have IPv6 configured. The IP swap will NOT handle IPv6 addresses." | errorlogit 3 root
		fi
		ec lightRed "Please abort with Control+C if this doesn't look right!"
		say_ok

		ec red "Don't forget, the final sync for an IP swap will be INTERACTIVE following the data sync. Be ready to clear ARP and log into WHM once the final is finished to confirm changes."
		ec red "Please also bail here if you should not be taking the IPs from the source server, i.e. they are not routable at your destination location (and vice versa). If the two servers are using different VLANs, this will probably not work. Use your own brain, as this machine has none."
		ec lightRed "IF YOU PROCEED HERE WITHOUT CONFIRMING THAT IPS CAN BE SWAPPED, BOTH MACHINES WILL GO OFFLINE WHEN THE SYNC IS COMPLETE, REQUIRING IPMI OR PHYSICAL RECOVERY."
		say_ok
	fi
}
