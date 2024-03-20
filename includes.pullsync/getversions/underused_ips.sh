underused_ips() { # compare used ips to free ips as a percentage
	ec yellow "Checking IP utilization..."
	source_total_ips=$(sssh "/usr/local/cpanel/bin/whmapi1 listips | grep used\:\  | wc -l")
	[ $source_total_ips -eq 0 ] && source_total_ips=1 #dirty fix for div by 0
	source_used_ips=$(sssh "/usr/local/cpanel/bin/whmapi1 listips | grep used\:\ 1 | wc -l")
	source_ip_utilization=$(( 100 * $source_used_ips / $source_total_ips ))
	ec yellow "Source IP utilization is ${source_ip_utilization}% of $source_total_ips IP(s)."
	if [ $source_ip_utilization -le 80 -a $source_total_ips -gt 2 ]; then #dont warn on 50% usage for 2 IPs
		ec red "Source server is underutilizing (<80%)! Consider asking customer to reclaim some if they are swapping IPs!"
		say_ok
	fi
}
