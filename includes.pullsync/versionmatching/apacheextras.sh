apacheextras() { #run after successful ea, copies extra apache things not part of ea
	#TODO import individual settings from $dir/var/cpanel/conf/apache/local to /etc/cpanel/ea4/ea4.conf on EA4 servers

	# see if we can set the directory index variable
	if [ "$remoteea" = "EA3" ]; then
		local remotehttp_di=$(grep -E [\"\']?directoryindex[\"\']?\:\ [\"\']?[a-zA-Z0-9] $dir/var/cpanel/conf/apache/main | tail -1)
	else
		local remotehttp_di=$(awk -F\" '/\"directoryindex\"/ {print $4}' $dir/etc/cpanel/ea4/ea4.conf)
	fi
	if [ "$remotehttpd_di" ]; then
		ec yellow "Copying DirectoryIndex priority..."
		sed -i.pullsync.bak '/\"directoryindex\"\ \:/ s/\:\ \"[a-zA-Z0-9\ \.]*\"/\:\ \"'"$remotehttpd_di"'\"/' /etc/cpanel/ea4/ea4.conf
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
		httpd -t 2>&1 | stderrlogit 4
		if [ "${PIPESTATUS[0]}" = "0" ]; then
			# config test was ok
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
			ec green "Success!"
		else
			# restart failed, revert
			ec red "Couldn't validate config after adjusting DirectoryIndex priority! Reverting changes..." | errorlogit 3
			[ -f /var/cpanel/conf/apache/main.pullsync.bak ] && mv -f /var/cpanel/conf/apache/main{.pullsync.bak,}
			[ -f /etc/cpanel/ea4/ea4.conf.pullsync.bak ] && mv -f /etc/cpanel/ea4/ea4.conf{.pullsync.bak,}
			/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
			/scripts/restartsrv_apache 2>&1 | stderrlogit 4
		fi
	fi
}
