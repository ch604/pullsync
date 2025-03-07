# shellcheck disable=SC2002
dnscheck() { #skip on versionmatching, as there will be no $domainlist. check the current dns and nameserver setup.
	[ ! "$domainlist" ] && ec yellow "No domain list, skipping dns checks." && return
	local nslist dnsdir
	ec yellow "Checking Current DNS..."
	dnsdir="$dir/dnsoutput"
	mkdir "$dnsdir"

	# set source_ips if not just checking DNS
	[ "$ip" ] && source_ips=$(sssh "/scripts/ipusage" | awk '{print $1}') || source_ips="0.0.0.0"
	if [ -f /var/cpanel/cpnat ]; then
		target_ips=$(for i in $(/scripts/ipusage | awk '{print $1}'); do grep -Eq "^$i [0-9]+" /var/cpanel/cpnat && awk '/^'"$i"' / {print $2}' /var/cpanel/cpnat || echo "$i"; done)
	else
		target_ips=$(/scripts/ipusage | awk '{print $1}')
	fi

	#loop through domains and sort them by where they resolve
	export source_ips target_ips dnsdir
	# shellcheck disable=SC2086
	parallel -j 100% -u 'parallel_dnslookup {}' ::: $domainlist

	#generate traditional dns.txt
	cat "$dnsdir/target.txt" "$dnsdir/no_resolve.txt" "$dnsdir/source.txt" "$dnsdir/not_here.txt" 2> /dev/null | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" | while read -r dom ip ns1 ns2; do echo -e "$dom\t$ns1\t$ns2\t$ip" >> "$dir/dns.txt"; done

	#collect most used nameservers
	ec yellow "Checking nameservers..."
	nslist=$(cat "$dnsdir/source.txt" "$dnsdir/not_here.txt" 2> /dev/null | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" | awk '{print $3 "\n" $4}' | sort -u)
	# shellcheck disable=SC2086
	[ "$nslist" ] && parallel -j 100% -u 'parallel_nslookup {}' ::: $nslist | sort -rVk 2 > "$dnsdir/nameserver_summary.txt"

	#summarize
	ec white "\nDNS Records\n"
	echo "_ Source Target Elsewhere No_Resolve
	A $(cat "$dnsdir/source.txt" 2> /dev/null | wc -l) $(cat "$dnsdir/target.txt" 2> /dev/null | wc -l) $(cat "$dnsdir/not_here.txt" 2> /dev/null | wc -l) $(cat "$dnsdir/no_resolve.txt" 2> /dev/null | wc -l)
	MX $(cat "$dnsdir/mx.source.txt" 2> /dev/null | wc -l) $(cat "$dnsdir/mx.target.txt" 2> /dev/null | wc -l) $(cat "$dnsdir/mx.not_here.txt" 2> /dev/null | wc -l) $(cat "$dnsdir/mx.no_resolve.txt" 2> /dev/null | wc -l)" | column -t
	echo ""
	if [ "$nslist" ]; then
		ec yellow "The top 4 nameservers in use are:"
		head -4 "$dnsdir/nameserver_summary.txt" | awk '{print $1}' | logit
		grep -q ns.cloudflare "$dnsdir/nameserver_summary.txt" && ec yellow "Some sites are using cloudflare, which can skew these numbers towards appearing as \"other systems\"."
	fi
	echo ""
	ec yellow "All data is located at $dnsdir. A traditional dns.txt exists in $dir."

	#upload dns details for sites resolving to the source server only, warn if no sites resolve to source
	if [ -f "$dnsdir/source.txt" ]; then
		dns_url=$(cat "$dnsdir/source.txt" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | haste) #strip color codes
		echo "$dns_url" >> "$dnsdir/dns_url.txt"
		ec yellow "DNS details for domains that resolve to the source server have been uploaded to ${dns_url}."
	else
		ec lightRed "No domains resolve to the source server. You might not need to do this migration unless these are development sites. Confirm that you really need to proceed."
	fi

	#warn if any sites involved resolve to the target server already.
	if [[ -s $dnsdir/target.txt || -s $dnsdir/mx.target.txt ]]; then
		ec lightRed "Some domains resolve to this server! Double check $dnsdir/target.txt and $dnsdir/mx.target.txt before continuing!"
		ec lightRed "YOU MIGHT OVERWRITE LIVE DATA IF YOU CONTINUE! MAKE SURE THIS IS WHAT YOU WANT TO DO!"
	fi
	echo ""
	[ ! -s "$dir/dns/mx.source.txt" ] && ec white "There are no sites with MX records that resolve to the source server (checked $dir/dns/mx.source.txt)."
	say_ok
}
