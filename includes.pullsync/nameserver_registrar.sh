nameserver_registrar() { #takes $1 as a nameserver to find the registrar for. run a whois and strip out the necessary info.
	local reg_junk
	[ ! "$1" ] && return # exit if there is no nameserver passed
	reg_junk=$(mktemp)
	whois -H "$(cut -d. -f2- <<< "$1")" > "$reg_junk" 2> /dev/null
	if grep -q "^Reseller:" "$reg_junk"; then
		# reseller registrar
		awk -F: '/^Reseller:/ {print $2}' "$reg_junk" | sed 's/^\ //' | tail -1
	else
		# regular registrar
		awk -F: '/^\s*Registrar:/ {print $NF}' "$reg_junk" | sed 's/^\ //' | tail -1
	fi
	# remove the temp file
	rm -f "$reg_junk"
}
