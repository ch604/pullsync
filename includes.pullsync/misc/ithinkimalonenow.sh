ithinkimalonenow() { #check for multiple logins at startup
	local sessioncount=$(who | awk '{print $5}' | awk -F":S" '{print $1}' | sort -u | wc -l)
	[ $sessioncount -gt 1 ] && ec lightRed "There seem to be multiple users logged into the server!" && who && ec lightRed "Press enter if it is safe to proceed." && say_ok
}
