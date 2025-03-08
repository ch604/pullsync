set_ipv6() { #add ipv6 address from enabled pool to user, passed as $1
	local activeipv6pool
	ec yellow "Assigning IPv6 address to $1..."
	activeipv6pool=$(whmapi1 ipv6_range_list --output=json | jq -r '.data.range[] | if .enabled == 1 then .name else empty end' | head -1)
	whmapi1 ipv6_enable_account user="$1" range="$activeipv6pool" &> /dev/null
}
