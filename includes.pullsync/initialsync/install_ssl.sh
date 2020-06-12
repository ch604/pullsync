install_ssl() { #install ssls for restored account. $1 is username.
	local user=$1
	local user_domains=`grep ^DNS /var/cpanel/users/${user} |cut -d= -f2 |grep -v \*`
	for domain in ${user_domains}; do
		# check for ssl from old server
		if [ -f ${dir}/var/cpanel/userdata/${domain}_SSL ]; then
			certfile=$(grep ^sslcertificatefile\: ${dir}/var/cpanel/userdata/${domain}_SSL | awk '{print $2}')
			keyfile=$(grep ^sslcertificatekeyfile\:  ${dir}/var/cpanel/userdata/${domain}_SSL | awk '{print $2}')
			cabundle=$(grep ^sslcacertificatefile\: ${dir}/var/cpanel/userdata/${domain}_SSL | awk '{print $2}')
			if [ "${cabundle}" -a "${keyfile}" -a "${cabundle}" ]; then
				# if all necessary files exist, install ssl through whmapi
				ec white "Installing SSL certificate for ${domain}..."
				/usr/local/cpanel/bin/whmapi1 installssl domain=${domain} crt=$(cat ${dir}/${certfile} | perl -MURI::Escape -ne 'print uri_escape($_)') key=$(cat ${dir}/${keyfile} | perl -MURI::Escape -ne 'print uri_escape($_)') cab=$(cat ${dir}/${cabundle} | perl -MURI::Escape -ne 'print uri_escape($_)') 2>&1 | stderrlogit 3
			fi
		fi
	done
}
