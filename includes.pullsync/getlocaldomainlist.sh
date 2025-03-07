getlocaldomainlist() { #just build domainlist off of userlist, used for generating hostsfile entries
	domainlist=$(for user in $userlist; do
		[ -f /var/cpanel/users/$user ] && awk -F= '/^DNS.*=/ {print $2}' /var/cpanel/users/$user
	done)
	echo $domainlist > $dir/domainlist.txt
}
