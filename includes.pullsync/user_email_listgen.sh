user_email_listgen() { #return mailbox list for given cpanel user
	local user userhome_remote emaildomlist
	user=$1
	userhome_remote=$(awk -F: '/^'"$user"':/ {print $6}' "$dir/etc/passwd")
	emaildomlist=$(awk -F= '/^DNS[0-9]*=/ {print $2}' "$dir/var/cpanel/users/$user")
	for dom in $emaildomlist; do
		for box in $(sssh "find $userhome_remote/mail/$dom/ -maxdepth 1 -mindepth 1 -type d -printf \"%f\n\" 2> /dev/null"); do
			echo "mail/$dom/$box"
		done
	done
	sssh "[ -d $userhome_remote/mail/new 2> /dev/null ]" && echo "mail/new"
}
