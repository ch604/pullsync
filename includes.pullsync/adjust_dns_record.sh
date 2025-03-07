adjust_dns_record() { #supports setting hostname and nameserver records. requires domain to adjust as $1 and ip address as $2
	local dom domroot domsub newip linenum
	dom=$1
	domroot=$(awk -F. '{print $(NF-1)"."$NF}' <<< "$dom")
	domsub=$(rev <<< "$dom" | cut -d. -f3- | rev)
	newip=$2
	if /usr/local/cpanel/bin/whmapi1 listzones 2> /dev/null | grep -q " domain: $dom"; then #discreet zone exists, which means it must already have an A record
	 	linenum=$(awk '/^'"$dom"'\..*[[:space:]]A[[:space:]]/ {print NR; exit}' "/var/named/$dom.db")
		/usr/local/cpanel/bin/whmapi1 editzonerecord domain="$dom" line="$linenum" name="$dom." class=IN ttl=3600 type=A address="$newip" 2>&1 | stderrlogit 3
	elif /usr/local/cpanel/bin/whmapi1 listzones 2> /dev/null | grep -q " domain: $domroot"; then #zone for main domain, may or may not have A record
	 	linenum=$(awk '/^'"$domsub"'[[:space:]].*[[:space:]]A[[:space:]]/ {print NR; exit}' "/var/named/$domroot.db")
		if [ "$linenum" ]; then #A record already exists, adjust it
			/usr/local/cpanel/bin/whmapi1 editzonerecord domain="$domroot" line="$linenum" name="$domsub" class=IN ttl=3600 type=A address="$newip" 2>&1 | stderrlogit 3
		else
			/usr/local/cpanel/bin/whmapi1 addzonerecord domain="$domroot" name="$domsub" class=IN ttl=3600 type=A address="$newip" 2>&1 | stderrlogit 3
		fi
	else #no zone exists, add one
		/usr/local/cpanel/bin/whmapi1 adddns domain="$dom" ip="$newip" 2>&1 | stderrlogit 3
	fi
	rndc reload 2>&1 | stderrlogit 4
}
