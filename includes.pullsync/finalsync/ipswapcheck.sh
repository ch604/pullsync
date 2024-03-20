ipswapcheck() { #logic check and query tech as to whether an ip swap should be performed, called during finalsync_main()
	[ ! -e $dir/usr/local/lp/etc/lp-UID ] && ec yellow "Source server doesn't seem to be at LW, skipping IP swap logic." && return
	local remotecount=$(echo $userlist | wc -w)
	local localcount=$(\ls -A /var/cpanel/users/ | egrep -vx "${badusers}" | wc -w)

	# check if both source and target are vps (already filtered out the non-lw sources) and offer A to C ip migration
	if df | awk '{print $1}' | grep -qE 'vda[0-9]' && sssh "df" | awk '{print $1}' | grep -qE 'vda[0-9]'; then
		ec yellow "Both source and target server appear to be Storm. Skipping IP swap logic."
		unset ipswap
#		ec red "DONT ANSWER YES IF YOU ARENT SURE"
#		if yesNo "Is this a Zone A to Zone C IP reassignment final sync?"; then
#			[ ! "${STY}" ] && ec red "You do not seem to be in a screen session! The IP swap will destroy the running script when the networking changes! I'm exiting now, please restart the script in a screen." && exitcleanup 80
#			[ $remotecount -ne $localcount ] && ec red "Userlist count is DIFFERENT between both servers (counted $remotecount and $localcount)! ABORT!" && exitcleanup 50
#			[ ! -d $dir/var/cpanel/userdata -o ! -d $dir/var/cpanel/users -o ! -f $dir/etc/named.conf -o ! -d $dir/var/named -o ! -d $dir/etc/sysconfig/network-scripts ] && ec red "Unable to find all the files I need in $dir! I'm outta here!" && exitcleanup 50
#			if sssh "which ip &> /dev/null"; then
#				sssh "ip addr show dev \$(grep ETHDEV /etc/wwwacct.conf | awk '{print \$2}') | grep inet\ | awk '{print \$2}' | cut -d\/ -f1 | grep -v 127.0.0.1" >> $dir/ips.txt
#			else
#				sssh "for each in \$(ifconfig | grep ^\$(grep ETHDEV /etc/wwwacct.conf | awk '{print \$2}' | cut -d\: -f1) | awk '{print \$1}'); do ifconfig \$each | grep inet\ ; done | awk '{print \$2}' | cut -d\: -f2 | grep -v 127.0.0.1" >> $dir/ips.txt
#			fi
#			[ ! -s $dir/ips.txt ] && ec red "Unable to collect list of IPs from source server! Is the program 'ip' or 'ifconfig' available there?" && exitcleanup 50
#			ec yellow "The following IPs will be added to this server following the sync (abort if this doesn't look right):"
#			cat $dir/ips.txt
#			stormipswap=1
#			ec red "A storm ip swap will be INTERACTIVE following the data sync. You will need to perform some actions from your workstation. Don't worry, I'll give you the commands."
#			ec red "Please do an additional sanity check NOW in billing to make sure you are swapping IPs from a ZONE A server to a ZONE C server. Bail if you aren't."
#			say_ok
#		fi
	# since both servers are not vps, see if just one of them is and skip ip swap if so
	elif df | awk '{print $1}' | grep -qE 'vda[0-9]' || sssh "df" | awk '{print $1}' | grep -qE 'vda[0-9]'; then
		ec yellow "Source and target server are different platforms, skipping IP swap logic."
		unset ipswap
	# make sure that source and target are either both nat or both non-nat (TODO doesnt make sure that the prefixes match)
	elif [ "$(echo $cpanel_main_ip | grep -E "^($natprefix)")" -a "$(echo $ip | grep -vE "^($natprefix)")" ] || [ "$(echo $ip | grep -E "^($natprefix)")" -a "$(echo $cpanel_main_ip | grep -vE "^($natprefix)")" ]; then
		ec yellow "One server has natted IPs, and the other does not ($ip, $cpanel_main_ip). Skipping IP swap logic."
		unset ipswap
	# we should be left with lw-only dedi to dedi servers, ask if ip swap
	elif yesNo "Is this an IP swap final sync? (WARNING this feature is not IPv6 compatible!)"; then
		[ ! "${STY}" ] && ec red "You do not seem to be in a screen session! The IP swap will destroy the running script when the networking changes! I'm exiting now, please restart the script in a screen." && exitcleanup 80
		[ $remotecount -ne $localcount ] && ec red "Userlist count is DIFFERENT between both servers (counted $remotecount and $localcount)! ABORT!" && exitcleanup 50
		[ ! -d $dir/var/cpanel/userdata -o ! -d $dir/var/cpanel/users -o ! -f $dir/etc/named.conf -o ! -d $dir/var/named -o ! -d $dir/etc/sysconfig/network-scripts ] && ec red "Unable to find all the files I need in $dir! I'm outta here!" && exitcleanup 50
		# per #139, disabled ipswap temporarily. uncomment these lines and remove uncommented lines till "end" to swap back.
		# ipswap=1
		# ec red "Don't forget, the final sync for an IP swap will be INTERACTIVE following the data sync. Be ready to clear ARP at https://noc.liquidweb.com/core/arpmac/ and log into WHM once the final is finished to confirm changes."
		# ec red "Please also bail here if you are not swapping between TWO DEDICATED SERVERS in the SAME SECTION. If the two servers are using different VLANs, you should open the appropriate page in NOC to update the switchport VLAN. Use your own brain, as this machine has none."
		unset ipswap
		dummyipswap=1
		ec red "Good to know. I'm not going to do anything about that.

You are now responsible for doing ALL ip swap tasks, to ensure that you have complete comfort with the procedure."
		ec white "Please check the waypoint article https://waypoint.liquidweb.com/display/MIG/cPanel+IP+Swap for the complete procedure."
		# end edit for #139
		say_ok
		if rpm -q --quiet yumconf-serversecureplus; then
			ec red "This server is running serversecure plus! Make sure you let the security team know about the IP swap when you are done! You will need to create a new internal ticket with the following note and hand it off to the security team queue:"
			ec white "Hello, the server $(hostname), $(cat /usr/local/lp/etc/lp-UID), just had an IP swap and is running SS+. Please update the SS+ database as needed for the new IP, ${ip}. Thank you!"
			say_ok
		fi
	fi
}
