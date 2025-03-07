ithinkimalonenow() { #check for multiple logins at startup
	if [ "$(who | awk '{print $5}' | awk -F":S" '{print $1}' | sort -u | wc -l)" -gt 1 ]; then
		ec lightRed "There seem to be multiple users logged into the server!"
		who
		ec lightRed "Press enter if it is safe to proceed."
		say_ok
	fi
}
