nameserver_registrar() { #takes $1 as a nameserver to find the registrar for. run a whois and strip out the necessary info.
	[ ! "$1" ] && return # exit if there is no nameserver passed
	# store the output in a temp file
	reg_junk=$(mktemp)
	whois -H $(echo $1 | cut -d. -f2-5) 2> /dev/null | grep -E -e "^Reseller\:" -e "^[[:space:]]*Registrar\:" > ${reg_junk}
	if [ "$(grep ^Reseller\: ${reg_junk} | cut -d\: -f2 | tr -d ' ')" ]; then
		# reseller registrar
		echo $(grep -E ^Reseller\: ${reg_junk} | cut -d\: -f2 | sed 's/^\ //')
	else
		# regular registrar
		echo $(grep -E ^[[:space:]]*Registrar\: ${reg_junk} | awk -F: '{print $NF}' | tail -n1 | sed 's/^\ //')
	fi
	# remove the temp file
	rm -f ${reg_junk}
}
