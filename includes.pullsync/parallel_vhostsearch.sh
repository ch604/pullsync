parallel_vhostsearch() { #search for domain set up outside cpanel as $1
	domain=$1
	if ! grep -qRE " \"?$domain\"?(:|$)" "$dir/var/cpanel/userdata/"; then
		# output to missingvhosts.txt
		{ echo "$domain"
		sssh "httpd -S 2> /dev/null" | grep "namevhost $domain"
		echo "" ; } >> "$dir/missingvhosts.txt"
		# output to parent parallel process
		echo "$domain"
	fi
}