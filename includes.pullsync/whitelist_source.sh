whitelist_source() { #allow unfettered connections to $ip
	ec yellow "Whitelisting source IP in firewall..."
	if [ $(which csf 2> /dev/null) ] ; then
		csf -a $ip 2>&1 | stderrlogit 4
	elif [ $(which apf 2> /dev/null) ]; then
		apf -a $ip 2>&1 | stderrlogit 4
		apf -r &> /dev/null &
	else
		ec red "Could not detect CSF/APF! Install CSF please!"
		say_ok
	fi
}
