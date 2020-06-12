ea4phphandlercompare() { #attempt to compare php handler on ea4
	[ ! "$localphphandler" ] || [ ! "$remotephphandler" ] && return #cant continue if either variable is blank
	ec white "Local PHP handler:  $localphphandler"
	ec white "Remote PHP handler: $remotephphandler"
	if [ "$localphphandler" = "$remotephphandler" ]; then
		ec green "PHP handlers already match!"
	elif /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q $remotephphandler; then
		ec green "Remote PHP handler already compiled into EA and will be matched"
		matchhandler=$remotephphandler
	elif [ "$remotephphandler" = "fcgi" ] || [ "$remotephphandler" = "dso" ]; then
		[ "$remotephphandler" = "dso" ] && ec red "DSO is not available on this machine!"
		if yesNo "Use PHP-FPM?"; then
			matchhandler=cgi #cant use fcgi globally yet, will have to set it up per domain upon arrival
			fcgiconvert=1
			ec green "PHP-FPM will be installed via yum and set up as accounts arrive."
		fi
	else
		ec red "This combination doesn't fit current logic! Skipping handler match"
	fi
}
