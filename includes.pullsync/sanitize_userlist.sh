sanitize_userlist() { #remove bad users from the userlist and record it
	userlist=$(echo "$userlist" | sort -u | grep -Ev "^HASH" | grep -Evx "${badusers}")
	echo "$userlist" > $dir/userlist.txt
	echo "$userlist" > /root/userlist.txt
}
