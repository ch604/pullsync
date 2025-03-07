validate_license() {
	#break if cant reach verify.cpanel.net
	! host verify.cpanel.net &> /dev/null && return
	ec yellow "Validating cPanel license..."
	# need curl
	! which curl &> /dev/null && yum -y -q install curl 2>&1 | stderrlogit 4
	# make sure we have the latest license file locally
	/usr/local/cpanel/cpkeyclt &> /dev/null
	cpnat_check
	if grep -Eq ^$cpanel_main_ip\ [0-9]+ /var/cpanel/cpnat 2> /dev/null; then
		licensetestip=$(awk '/^'$cpanel_main_ip' [0-9]+/ {print $2}' /var/cpanel/cpnat)
	else
		licensetestip=$cpanel_main_ip
	fi
	# see if the main ip has an active license
	curl -sS -L https://verify.cpanel.net/app/verify?ip=${licensetestip} > $dir/validate_license_output.txt
	if ! grep -qE active\<br[\ ]?/\> $dir/validate_license_output.txt; then
		ec red "The server seems to be cPanel, but the license is invalid! Please make sure that the IP ${licensetestip} is properly licensed before the end of the migration!" | errorlogit 2
		say_ok
	fi
}
