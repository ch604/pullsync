printrdns() { #show rdns and warn if unset
	ec yellow "Printing current remote rDNS..."
	echo "$(cat "$dir/var/cpanel/mainip"): $(dig +short -x "$(cat "$dir/var/cpanel/mainip")")" | column -t | tee "$dir/rdns_remote.txt" | logit
	ec yellow "Printing current local rDNS..."
	for each in $(whmapi1 listips | awk '/public_ip: / {print $2}'); do
		echo "$each: $(dig +short -x "$each")"
	done | column -t | tee "$dir/rdns_local.txt" | logit
	[ ! "$(awk '{print $2}' < "$dir/rdns_local.txt")" ] && ec red "You don't have rDNS set up!"
	say_ok
}
