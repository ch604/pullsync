dnsclustering() { #warn if dns clustering is enabled on either server.
	ec yellow "Checking for DNS clustering..."
	if [ -f $dir/var/cpanel/useclusteringdns ] || [ -d $dir/var/cpanel/cluster/root/config/ ]; then
		ec lightRed 'Remote DNS Clustering found!'
		say_ok
	fi
	if [ -f /var/cpanel/useclusteringdns ]; then
		ec red "DNS cluster on the local server is detected, and ENABLED! You shouldn't continue since restoring accounts has the potential to automatically update DNS for them in the cluster. Recommended to disable clustering before continuing."
		[ "$autopilot" ] && exitcleanup 9
		say_ok
	elif [ -d /var/cpanel/cluster/root/config/ ]; then
		ec yellow "Local DNS clustering was found, but it is disabled."
	else
		ec yellow "No Local DNS clustering found."
	fi
}
