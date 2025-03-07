parallel_zonesearch() { #check if domain as $1 was set up outside of cpanel (e.g. not in userdata)
	domain=$1
	if ! grep -qRE " $domain(:|$)" "$dir/var/cpanel/userdata/"; then
		# output to missingdnszones.txt
		{ echo "$domain"
		grep -A3 "^zone \"$domain\"" "$dir/etc/named.conf"
		echo "" ; } >> "$dir/missingdnszones.txt"
		# output to parent parallel process
		echo "$domain"
	fi
}
