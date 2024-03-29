nameserver_registrar() { #takes $1 as a nameserver to find the registrar for. run a whois and strip out the necessary info.
	[ ! "$1" ] && return # exit if there is no nameserver passed
	# store the output in a temp file
	reg_junk=$(mktemp)
	whois -H $(echo $1 | cut -d. -f2-) 2>/dev/null > ${reg_junk}
	if grep -q ^Reseller\: ${reg_junk}; then
		# reseller registrar
		echo $(awk -F: '/^Reseller:/ {print $2}' ${reg_junk} | sed 's/^\ //')
	else
		# regular registrar
		echo $(awk -F: '/^\s*Registrar:/ {print $NF}' ${reg_junk} | tail -1 | sed 's/^\ //')
	fi
	# remove the temp file
	\rm -f ${reg_junk}
}
