dnscheck(){ #skip on versionmatching, as there will be no $domainlist. check the current dns and nameserver setup.
	if [ "$domainlist" ]; then
		ec yellow "Checking Current DNS..."

		#generate a traditional dns.txt file in the background
		((parallel -j 75% 'echo {}\ `dig @8.8.8.8 NS +short {} | sed '\''s/\.$//g'\'' | tail -2 | sort`\ `dig @8.8.8.8 +short {} | grep -v [a-zA-Z] | tail -1`' ::: $domainlist | grep -v \ \  | column -t > $dir/dns.txt) & )
		sleep 1

		# set source_ips if not just checking DNS
		[ "$ip" ] && source_ips=`sssh "/scripts/ipusage" | awk '{print $1}'` || source_ips="0.0.0.0"
		target_ips=`/scripts/ipusage| awk '{print $1}'`

		#set up some arrays
		local -a no_resolve not_here_resolve source_resolve target_resolve

		#loop through digging domains and sorting them by where they resolve
		for dom in $domainlist; do
			dig_ip=$(dig +short $dom @8.8.8.8 | grep -v [A-Za-z] | tail -1)
			if [ "$dig_ip" == "" ]; then
				no_resolve+=("$dom")
			else
				dig_ns=$(dig +short NS $dom @8.8.8.8 | sed 's/\.$//g' | tail -2 | sort | tr '\n' ' ')
				dom_line=$(printf "\e[32m%-60s\e[33m%s\t\t\e[36m%s\e[0m" "$dom" "$dig_ip" "$dig_ns")
				if echo $source_ips | grep -q $dig_ip; then
					source_resolve+=("$dom_line")
				elif echo $target_ips | grep -q $dig_ip; then
					target_resolve+=("$dom_line")
				else
					not_here_resolve+=("$dom_line")
				fi
			fi
		done

		#print resultant data by array
		header=$(printf "\e[35m\t\t%-50s %s\t%s\e[0m" "Domain Name" "Current Live Ip" "Nameservers")
		[ ! -z "$target_resolve" ] && printf "\n\n\e[31mThe following domains resolve to this server:\n\n$header\n\n$(for i in ${!target_resolve[@]}; do echo -e "\t${target_resolve[$i]}" | tee -a $dir/target_resolve.txt; done) \n\n\e[0m"
		[ ! -z "$source_resolve" ] && printf "\n\n\e[31mThe following domains resolve to the source server:\n\n$header\n\n$(for i in ${!source_resolve[@]}; do echo -e "\t${source_resolve[$i]}" | tee -a $dir/source_resolve.txt; done) \n\n\e[0m"
		[ ! -z "$not_here_resolve" ] && printf "\n\n\e[31mThe following domains do not resolve to either server:\n\n$header\n\n$(for i in ${!not_here_resolve[@]}; do echo -e "\t${not_here_resolve[$i]}" | tee -a $dir/not_here_resolve.txt; done) \n\n\e[0m"
		[ ! -z "$no_resolve" ] && printf "\n\n\e[31mThe following domains do not resolve at all:\e[32m\n\n$(for i in ${no_resolve[*]}; do echo -e "\t$i" | tee -a $dir/no_resolve.txt; done) \n\n\e[0m"

		#print out most used nameservers
		echo -e "\nNameserver summary:\n"
		echo -e "Nameserver\tOccurrences\tIP\tRegistrar"
		for each in $(cat $dir/source_resolve.txt $dir/not_here_resolve.txt 2>/dev/null | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" | awk '{print $3 "\n" $4}' | sort -u); do
			local registrar=$(nameserver_registrar $each)
			echo "$each $(grep $each $dir/source_resolve.txt $dir/not_here_resolve.txt 2>/dev/null | wc -l) $(dig +short $each @8.8.8.8 | head -1) $registrar"
		done | sort -rVk 2 | column -t| tee -a $dir/nameserver_summary.txt
		echo -e "\n"
		ec yellow "A traditional dns.txt was generated at $dir/dns.txt if needed."

		#upload dns details for sites resolving to the source server only, warn if no sites resolve to source
		if [ -f $dir/source_resolve.txt ]; then
			dns_url=$(cat $dir/source_resolve.txt | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | haste) #strip color codes
			echo $dns_url >> $dir/dns_url.txt
			ec yellow "DNS details for domains that resolve to the source server have been uploaded to ${dns_url}, if you need to provide this information to the customer."
		else
			ec lightRed "No domains resolve to the source server. You might not need to do this migration unless these are development sites. Confirm that you really need to proceed."
		fi

		#warn if any sites involved resolve to the target server already.
		[ -f $dir/target_resolve.txt ] && ec lightRed "Some domains resolve to this server! Double check $dir/target_resolve.txt before continuing!" && ec lightRed "YOU MIGHT OVERWRITE LIVE DATA IF YOU CONTINUE! MAKE SURE THIS IS WHAT YOU WANT TO DO!"
		say_ok
	fi
}
