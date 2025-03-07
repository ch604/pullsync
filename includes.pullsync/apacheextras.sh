apacheextras() { #run after successful ea, copies extra apache things not part of ea
	local remotehttp_di localhttp_di
	#TODO import individual settings from $dir/var/cpanel/conf/apache/local to /etc/cpanel/ea4/ea4.conf on EA4 servers

	# see if we can set the directory index variable
	if [ "$remoteea" == "EA3" ]; then
		remotehttp_di=$(grep -E "[\"']?directoryindex[\"']?: [\"']?[a-zA-Z0-9]" "$dir/var/cpanel/conf/apache/main" | tail -1)
	else
		remotehttp_di=$(awk -F\" '/\"directoryindex\"/ {print $4}' "$dir/etc/cpanel/ea4/ea4.conf")
	fi
	localhttp_di=$(awk -F\" '/\"directoryindex\"/ {print $4}' /etc/cpanel/ea4/ea4.conf)
	if [ "$remotehttp_di" ] && [ ! "$remotehttp_di" == "$localhttp_di" ]; then
		ec yellow "$hg Copying DirectoryIndex priority"
		sed -i.pullsync.bak '/\"directoryindex\"\ \:/ s/\:\ \"[a-zA-Z0-9\ \.]*\"/\:\ \"'"$remotehttp_di"'\"/' /etc/cpanel/ea4/ea4.conf
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
		#TODO this will always validate ok, httpd doesnt care if your DirectoryIndex is populated. leaving the rest of this function in here in case other adjustments are made in the future to ea4.conf or httpd.conf.
		httpd -t 2>&1 | stderrlogit 4
		if [ "${PIPESTATUS[0]}" -eq 0 ]; then
			# config test was ok
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
			writecm
		else
			# restart failed, revert
			writexx
			ec red "Couldn't validate config after adjusting DirectoryIndex priority! Reverting changes..." | errorlogit 3 root
			[ -f /var/cpanel/conf/apache/main.pullsync.bak ] && mv -f /var/cpanel/conf/apache/main{.pullsync.bak,}
			[ -f /etc/cpanel/ea4/ea4.conf.pullsync.bak ] && mv -f /etc/cpanel/ea4/ea4.conf{.pullsync.bak,}
			/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
			/scripts/restartsrv_apache 2>&1 | stderrlogit 4
		fi
	fi
}