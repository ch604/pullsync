useallusers() { #on certain functions that could be for all users or a userlist, detect userlist.txt and offer to use it.
	if [ -s /root/userlist.txt ]; then
		ec yellow "/root/userlist.txt has $(wc -w < /root/userlist.txt 2> /dev/null || echo 0) users in it. First few users: $(paste -sd' ' /root/userlist.txt | cut -d' ' -f1-10)"
		if yesNo "Use /root/userlist.txt? (otherwise I'll do all users)"; then
			userlist=$(cat /root/userlist.txt)
		fi
	fi
	[ ! "$userlist" ] && userlist=$(find /var/cpanel/users/ -maxdepth 1 -type f -printf "%f\n")
	sanitize_userlist
}
