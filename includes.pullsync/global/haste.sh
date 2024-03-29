haste() { #upload stdin to a hastebin, return the url as stdout. usage: myurl=$(echo "foo bar baz" | haste) ; echo $myurl
	# update if different haste server in use
	hastebin_url="liquidwebpagetest.com"
	if ! host $hastebin_url &> /dev/null; then
		# if haste server cant be resolved, use the ip as a backup
		hastebin_url="67.225.133.14"
	fi
	local pbfile=$(mktemp)
	cat - > $pbfile ;
	curl -X POST -s --data-binary @${pbfile} https://${hastebin_url}/documents | awk -F '"' -v url=$hastebin_url '{print "https://" url "/raw/"$4}'
	\rm -f $pbfile
}
