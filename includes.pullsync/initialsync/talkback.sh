talkback() { # give specific sync metadata to the talkback server
	ec yellow "Getting Talkback information..."

	# get variables
	source_dc=$(whois $ip 2>/dev/null | grep -e ^Organization -e ^descr: | tail -1 | awk '{for(i=2;i<=NF;++i)printf $i""FS; print ""}')
	# if source_dc is not set, likely its a natted source ip, and therefore an internal migration. added this line so i can verify this is the case.
	[ ! "$source_dc" ] && source_dc=$ip
	# access_level=root.cpanel hardcoded due to being pullsync and all
	host_type=$(virt-what)
	[ ! "$host_type" ] && host_type=dedicated
	account_count=$(echo $userlist | wc -w)
	local attended=$(($handsoffepoch - $starttimeepoch))
	local unattended=$(($(date +%s) - $handsoffepoch))
	[ "$iusedrepquota" = 1 ] && local volume=$remote_used_space

	ec yellow "Posting this to the Talkback page!"
	postme="$source_dc;root;cpanel;$host_type;$account_count;$attended;$unattended;$volume"
	echo $postme | tee $dir/talkback.txt
	result=$(curl -s https://docs.google.com/forms/d/e/1FAIpQLSfkBARcxxhg4su4bnipiuG2NUCH39rrV6LiSdqkJDKizbH7tQ/formResponse -d ifq -d entry.800527955="$source_dc" -d entry.1935396593="root" -d entry.1898733927="cpanel" -d entry.575001110="$host_type" -d entry.945689647="$account_count" -d entry.1387519561="$attended" -d entry.914393140="$unattended" -d entry.36071026="$volume" -d submit=Submit)
	if ! echo $result | grep -q "Your response has been recorded."; then
		ec red "Unable to post to Talkback form! Please post $dir/talkback.txt contents manually at https://lqdwb.cc/78f64tAv2" | errorlogit 4
	fi
}
