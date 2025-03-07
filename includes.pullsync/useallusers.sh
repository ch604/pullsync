useallusers() { #on certain functions that could be for all users or a userlist, detect userlist.txt and offer to use it.
	if [ -s /root/userlist.txt ]; then
		ec yellow "/root/userlist.txt has $(cat /root/userlist.txt | wc -w) users in it. First few users: $(cat /root/userlist.txt | tr '\n' ' ' | cut -d' ' -f1-10)"
		if yesNo "Use /root/userlist.txt? (otherwise I'll do all users)"; then
			userlist=$(cat /root/userlist.txt | egrep -v "^HASH" | egrep -vx "${badusers}")
		else
			userlist=$(\ls -A /var/cpanel/users | egrep -v "^HASH" | egrep -vx "${badusers}")
		fi
	else
		userlist=$(\ls -A /var/cpanel/users | egrep -v "^HASH" | egrep -vx "${badusers}")
	fi
}
