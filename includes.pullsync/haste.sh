haste() { #upload stdin to a hastebin, return the url as stdout. usage: myurl=$(echo "foo bar baz" | haste) ; echo $myurl
	[ -n "$hastebin_url" ] || return 1
	local pbfile
	# update if different haste server in use
	pbfile=$(mktemp)
	cat - > "$pbfile"
	curl -X POST -s --data-binary @"$pbfile" "https://${hastebin_url}/documents" | awk -F '"' -v url="$hastebin_url" '{print "https://" url "/raw/"$4}'
	rm -f "$pbfile"
}
