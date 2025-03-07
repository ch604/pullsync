parallel_dnslookup() { #look up whether a domain resolves, where it resolves to, and output to the appropriate file
	local dig_ip dig_ns dig_mx mx_a dom_line mx_line _y _x
	dig_ip=$(dig +short "$1" @8.8.8.8 | grep -v "[A-Za-z]" | tail -1)
	if [ "$dig_ip" == "" ]; then
		echo "$1" >> "$dnsdir/no_resolve.txt"
	else
		dig_ns=$(dig +short NS "$1" @8.8.8.8 | awk '{gsub("\\.$", ""); print tolower($0)}' | tail -2 | sort | paste -sd' ')
		dig_mx=$(dig +short MX "$1" @8.8.8.8 | awk '{gsub("\\.$", ""); print tolower($2)}' | sort | paste -sd' ')
		mx_a=$(for z in $dig_mx; do
			dig +short "$z" @8.8.8.8 | grep -v "[A-Za-z]" | tail -1
		done | sort -nu | paste -sd' ')
		dom_line=$(printf "\e[32m%-40s\e[33m%s\t\t\e[36m%s\e[0m" "$1" "$dig_ip" "$dig_ns")
		mx_line=$(printf "\e[32m%-40s\e[33m%s\t\t\e[36m%s\e[0m" "$1" "$dig_mx" "$mx_a")
		# a record
		if echo "$source_ips" | grep -q "$dig_ip"; then
			echo "$dom_line" >> "$dnsdir/source.txt"
		elif echo "$target_ips" | grep -q "$dig_ip"; then
			echo "$dom_line" >> "$dnsdir/target.txt"
		else
			echo "$dom_line" >> "$dnsdir/not_here.txt"
		fi
		# mx record
		for z in $mx_a; do #account for multiple mx records
			echo "$source_ips" | grep -q "$z" && _y=1
			echo "$target_ips" | grep -q "$z" && _x=1
		done
		if [[ "$_y" || "$_x" ]]; then #account for the possibility that mx can resolve to source AND target
			[ "$_y" ] && echo "$mx_line" >> "$dnsdir/mx.source.txt"
			[ "$_x" ] && echo "$mx_line" >> "$dnsdir/mx.target.txt"
		elif [ "$mx_a" ]; then #none of the mx records are on source or target
			echo "$mx_line" >> "$dnsdir/mx.not_here.txt"
		else #there are no mx records that resolve to ips
			echo "$1" >> "$dnsdir/mx.no_resolve.txt"
		fi
	fi
}
