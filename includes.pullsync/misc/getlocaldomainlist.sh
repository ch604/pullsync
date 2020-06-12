getlocaldomainlist() { #just build domainlist off of userlist, used for generating hostsfile entries
	domainlist=$(for user in $userlist; do
		grep ^DNS.*= /var/cpanel/users/$user | cut -d= -f2
	done)
	echo $domainlist > $dir/domainlist.txt
}
