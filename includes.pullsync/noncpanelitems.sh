noncpanelitems() { #look for non-cpanel listening services, vhosts, linux users, and zonefiles to warn tech
	ec yellow "Checking for non-cpanel items:"
	local _a _b _c _d _e
	_a=0; _b=0; _c=0; _d=0; _e=0

	#users
	ec yellow " Users..."
	noncpanelusers="$(cut -d: -f1 "$dir/etc/passwd" | grep -Evx -e "(${systemusers})" -e "($(find "$dir/var/cpanel/users/" -maxdepth 1 -type f -printf "%f\n" | paste -sd\|))")"
	for user in $noncpanelusers; do
		if ! grep -q "^$user:" /etc/passwd; then
			(( _a+=1 ))
			{ echo "$user"
			grep "^$user:" "$dir/etc/passwd"
			echo "" ; } >> "$dir/missinglinuxusers.txt"
		fi
	done
	[ "$_a" -ne 0 ] && ec red "$_a non-cpanel linux users detected on source!"

	#vhosts
	ec yellow " VirtualHosts..."
	# make sure we can get a list of vhosts
	if sssh "httpd -S &> /dev/null"; then
		# shellcheck disable=SC2046
		_b=$(parallel -j 100% -u 'parallel_vhostsearch {}' ::: $(sssh "httpd -S 2> /dev/null" | awk '/namevhost/ && !/localhost / {print $4}' | sort -u | grep -Ev "${valid_ip_format}" | sed 's/_wildcard_/\\\*/g') | wc -l)
		[ "$_b" -ne 0 ] && ec red "$_b vhosts on source not in cpanel!"
	else
		ec white "Couldn't execute 'httpd -S' on source, skipping this test."
	fi

	#zonefiles
	if [ -f "$dir/var/cpanel/useclusteringdns" ]; then
		ec green " Skipping DNS record check due to DNS cluster."
	else
		ec yellow " DNS records..."
		# shellcheck disable=SC2046
		_c=$(parallel -j 100% -u 'parallel_zonesearch {}' ::: $(awk -F\" '/^zone/ && !/\.arpa"/ && !/\.template\.liquidweb\.com"/ {print $2}' "$dir/etc/named.conf" | sort -u) | wc -l)
		[ "$_c" -ne 0 ] && ec red "$_c zonefiles on source not in cpanel!"
	fi

	#enabled services
	ec yellow " Enabled services..."
	# get enabled services with systemctl or chkconfig
	if sssh 'which systemctl &> /dev/null'; then
		sssh "systemctl list-unit-files" | awk '$2 == "enabled" {print $1}' | grep -Ev '(target|socket|path)$' | sed -e 's/\.service$//g' | grep -Ev "(^${systemservices}$)" > "$dir/remoterunlist.txt"
	else
		sssh "chkconfig --list" | awk '$5 == "3:on" {print $1}' | grep -Ev "(^${systemservices}$)" > "$dir/remoterunlist.txt"
	fi
	if which systemctl &> /dev/null; then
		systemctl list-unit-files | awk '$2 == "enabled" {print $1}' | grep -Ev '(target|socket|path)$' | sed -e 's/\.service$//g' > "$dir/localrunlist.txt"
	else
		chkconfig --list | awk '$5 == "3:on" {print $1}' > "$dir/localrunlist.txt"
	fi
	if grep -qv -f "$dir/localrunlist.txt" "$dir/remoterunlist.txt"; then
		# list services not on target
		while read -r service; do
			(( _d+=1 ))
			echo "$service" >> "$dir/missingservices.txt"
		done < <(grep -v -f "$dir/localrunlist.txt" "$dir/remoterunlist.txt")
	fi
	[ "$_d" -ne 0 ] && ec red "$_d services enabled on source which arent on target!"

	#listening services
	ec yellow " Listening services..."
	# most default listeners are enabled on both, so compare directly and only get differences. exclude mysql and variants because of name changes.
	sssh "netstat -plunt" | awk '{print $7}' | cut -d/ -f2 | sort -u | grep -Ev -e ^$ -e "(^mysq*|mariadb*|Address$)" | tr -d : > "$dir/remotelistening.txt"
	netstat -plunt | awk '{print $7}' | cut -d/ -f2 | sort -u | grep -Ev -e ^$ -e "(^mysq*|mariadb*|Address$)" | tr -d : > "$dir/locallistening.txt"
	if grep -qv -f "$dir/locallistening.txt" "$dir/remotelistening.txt"; then
		while read -r service; do
			(( _e+=1 ))
			echo "$service" >> "$dir/missinglisteners.txt"
		done < <(grep -v -f "$dir/locallistening.txt" "$dir/remotelistening.txt")
	fi
	[ "$_e" -ne 0 ] && ec red "$_e processes listening on source which arent on target!"

	#summary
	if [ $((_a+_b+_c+_d+_e)) -gt 0 ]; then
		ec red "Errors found with non-cpanel items! Please resolve issues listed in these files manually later if needed!" | errorlogit 4 root
		[ -f "$dir/missingdnszones.txt" ] && ec white "$dir/missingdnszones.txt" | errorlogit 4 root
		[ -f "$dir/missingvhosts.txt" ] && ec white "$dir/missingvhosts.txt" | errorlogit 4 root
		[ -f "$dir/missinglinuxusers.txt" ] && ec white "$dir/missinglinuxusers.txt" | errorlogit 4 root
		[ -f "$dir/missingservices.txt" ] && ec white "$dir/missingservices.txt" | errorlogit 4 root
		[ -f "$dir/missinglisteners.txt" ] && ec white "$dir/missinglisteners.txt" | errorlogit 4 root
		say_ok
	else
		ec green "No discrepancies detected. Weird."
	fi
}
