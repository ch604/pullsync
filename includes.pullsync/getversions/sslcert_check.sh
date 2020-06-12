sslcert_check() { # print cert info for all ssls in httpd.conf
	ec yellow "Checking for SSL Certificates..."
	if grep SSLCertificateFile $dir/usr/local/apache/conf/httpd.conf | grep -qv cpanel.pem; then
		# get a list of certs and start counting
		local i=0
		local now=$(date +"%s")
		for domain in $domainlist; do
			for crt in $(egrep 'SSLCertificateFile.*/(www\.)?'$domain'(\.crt|\/combined){1}' $dir/usr/local/apache/conf/httpd.conf | awk '{print $2}'; egrep 'SSLCertificateFile.*/(www_)?'$(echo $domain | tr '.' '_')'(\.crt|\/combined){1}' $dir/usr/local/apache/conf/httpd.conf | awk '{print $2}'); do
				# check with and without www, make temp file for multiple parses
				local crtout=$(mktemp)
				# stop echoing certs, saves screen space on larger migrations
				#ec white $dir$crt
				openssl x509 -noout -in $dir$crt -issuer  -subject  -dates > $crtout
				# set variable if using autossl
				grep -q -e "O=Let's Encrypt" -e "O=cPanel, Inc." $crtout && usingautossl=1
				local enddate=$(date -d "$(grep notAfter $crtout | cut -d\= -f2)" +"%s")
				# determine if any certs are expired
				[ "$enddate" -lt "$now" ] && local expiredcert=1
				rm -f $crtout
				i=$(($i + 1))
		 	done
		done
		ec yellow "There were $i certificates located for domains being migrated."
		[ $usingautossl ] && ec red "The source server seems to be using AutoSSL!"
		[ $expiredcert ] && ec red "The source server is using some expired SSL certificates." | errorlogit 4
		say_ok
	else
		ec yellow "No SSL Certificates found in httpd.conf."
	fi
}
