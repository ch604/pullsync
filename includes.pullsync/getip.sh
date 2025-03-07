getip() { #read and validate source ip
	if [ ! "$ip" ] || [[ ! "$ip" =~ $valid_ip_format ]]; then
		echo -e '\nSource IP: ' | logit
		rd ip
		while [[ ! $ip =~ $valid_ip_format ]]; do
			echo "Invalid format, please re-enter source IP:" | logit
			rd ip
		done
	fi
	if /scripts/ipusage | grep -q "^$ip " ; then
		ec lightRed "Hold it right there buckeroo. That IP belongs to the server you are logged into. I'm putting a stop to this."
		exitcleanup 3
	fi
}
