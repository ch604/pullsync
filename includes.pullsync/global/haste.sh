haste() { #upload stdin to a pastebin, return the url as stdout. usage: myurl=$(echo "foo bar baz" | haste) ; echo $myurl
	pastebin_url="hastebin.com"
	if ! host $pastebin_url &> /dev/null; then
		# if haste server cant be resolved, use the ip as a backup
		pastebin_url="172.64.102.8"
	fi
	local pbfile=$(mktemp)
	cat - > $pbfile ;
	curl -X POST -s --data-binary @${pbfile} https://${pastebin_url}/documents | awk -F '"' -v url=$pastebin_url '{print "https://" url "/raw/"$4}'
	rm -f $pbfile
}
