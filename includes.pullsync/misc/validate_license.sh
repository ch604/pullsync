validate_license() {
	#break if cant reach verify.cpanel.net
	! host verify.cpanel.net &> /dev/null && return
	ec yellow "Validating cPanel license..."
	# need curl
	! which curl &> /dev/null && yum -y -q install curl 2>&1 | stderrlogit 4
	# make sure we have the latest license file locally
	/usr/local/cpanel/cpkeyclt &> /dev/null
	if echo $cpanel_main_ip | grep -q -E "^($natprefix)" && [ ! -f /var/cpanel/cpnat ]; then
		/scripts/build_cpnat #build cpnat file here in case natted
	fi
	if grep -q $cpanel_main_ip /var/cpanel/cpnat 2> /dev/null; then
		licensetestip=$(grep ${cpanel_main_ip} /var/cpanel/cpnat | awk '{print $2}')
	else
		licensetestip=${cpanel_main_ip}
	fi
	# see if the main ip has an active license
	curl -sS -L https://verify.cpanel.net/app/verify?ip=${licensetestip} > $dir/validate_license_output.txt
	if ! grep -q active\<br/\> $dir/validate_license_output.txt; then
		ec red "The server seems to be cPanel, but the license is invalid! Please make sure that the IP ${licensetestip} is properly licensed before the end of the migration!" | errorlogit 2
		say_ok
	fi
}
