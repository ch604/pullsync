install_ssl() { #install ssls for restored account. $1 is username.
	local user user_domains cert key cabundle
	user=$1
	user_domains=$(awk -F= '/^DNS/ {print $2}' /var/cpanel/users/${user} | grep -v "\*")
	for domain in ${user_domains}; do
		# check for ssl from old server
		if grep -q ^${domain}___ $dir/ssls.txt; then
			cert=$(awk -F"___" '/^'${domain}'___/ {print $2}' $dir/ssls.txt)
			key=$(awk -F"___" '/^'${domain}'___/ {print $3}' $dir/ssls.txt)
			cabundle=$(awk -F"___" '/^'${domain}'___/ {print $4}' $dir/ssls.txt)
			if [[ "${cert}" && "${key}" && "${cabundle}" ]]; then
				ec white "Installing SSL certificate for ${domain}..."
				/usr/local/cpanel/bin/whmapi1 installssl domain=${domain} crt=${cert} key=${key} cab=${cabundle} 2>&1 | stderrlogit 3
			fi
		fi
	done
}
