ipswapcheck() { #logic check and query tech as to whether an ip swap should be performed, called during finalsync_main()
	local remotecount=$(echo $userlist | wc -w)
	local localcount=$(\ls -A /var/cpanel/users/ | egrep -vx "${badusers}" | wc -w)

	# make sure that source and target are either both nat or both non-nat (TODO doesnt make sure that the prefixes match)
	if [ "$(echo $cpanel_main_ip | grep -E "^($natprefix)")" -a "$(echo $ip | grep -vE "^($natprefix)")" ] || [ "$(echo $ip | grep -E "^($natprefix)")" -a "$(echo $cpanel_main_ip | grep -vE "^($natprefix)")" ]; then
		ec yellow "One server has natted IPs, and the other does not ($ip, $cpanel_main_ip). Skipping IP swap logic."
		unset ipswap
	elif yesNo "Is this an IP swap final sync? (WARNING this feature is not IPv6 compatible!)"; then
		[ ! "${STY}" ] && ec red "You do not seem to be in a screen session! The IP swap will destroy the running script when the networking changes! I'm exiting now, please restart the script in a screen." && exitcleanup 80
		[ $remotecount -ne $localcount ] && ec red "Userlist count is DIFFERENT between both servers (counted $remotecount and $localcount)! ABORT!" && exitcleanup 50
		[ ! -d $dir/var/cpanel/userdata -o ! -d $dir/var/cpanel/users -o ! -f $dir/etc/named.conf -o ! -d $dir/var/named -o ! -d $dir/etc/sysconfig/network-scripts ] && ec red "Unable to find all the files I need in $dir! I'm outta here!" && exitcleanup 50
		ipswap=1
		ec red "Don't forget, the final sync for an IP swap will be INTERACTIVE following the data sync. Be ready to clear ARP and log into WHM once the final is finished to confirm changes."
		ec red "Please also bail here if you should not be taking the IPs from the source server, i.e. they are not routable at your destination location (and vice versa). If the two servers are using different VLANs, this will probably not work.Use your own brain, as this machine has none."
		ec lightRed "IF YOU PROCEED HERE WITHOUT CONFIRMING THAT IPS CAN BE SWAPPED, BOTH MACHINES WILL GO OFFLINE WHEN THE SYNC IS COMPLETE, REQUIRING IPMI OR PHYSICAL RECOVERY."
		say_ok
	fi
}
