apacheextras() { #run after successful ea, copies extra apache things not part of ea
	if [ -f $dir/var/cpanel/conf/apache/local ] && [ "$localea" = "EA3" ]; then
		# there are apache setting includes from the old server, set them up and rebuild httpd
		#TODO import individual settings to /etc/cpanel/ea4/ea4.conf on EA4 servers
		ec yellow "Copying over WHM apache settings..."
		[ -f /var/cpanel/conf/apache/local ] && mv /var/cpanel/conf/apache/local{,.pullsync.bak}
		cp -a $dir/var/cpanel/conf/apache/local /var/cpanel/conf/apache/local
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
		httpd -t 2>&1 | stderrlogit 4
		if [ "${PIPESTATUS[0]}" = "0" ]; then
			# config test was ok
			/scripts/restartsrv_apache 2>&1 | stderrlogit 4
			ec green "Success!"
		else
			# restart failed, revert file
			ec red "Couldn't validate config after altering WHM apache settings! Reverting changes..." | errorlogit 3
			rm -f /var/cpanel/conf/apache/local
			[ -f /var/cpanel/conf/apache/local.pullsync.bak ] && mv /var/cpanel/conf/apache/local{.pullsync.bak,}
			/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
			/scripts/restartsrv_apache 2>&1 | stderrlogit 4
		fi
	fi

	# see if we can set the directory index variable
	if [ "$remoteea" = "EA3" ]; then
		local remotehttp_di=$(grep -E [\"\']?directoryindex[\"\']?\:\ [\"\']?[a-zA-Z0-9] $dir/var/cpanel/conf/apache/main | tail -1)
	else
		local remotehttp_di=$(awk -F\" '/\"directoryindex\"/ {print $4}' $dir/etc/cpanel/ea4/ea4.conf)
	fi
	if [ "$remotehttpd_di" ]; then
		ec yellow "Copying DirectoryIndex priority..."
		if [ "$localea" = "EA4" ]; then
			sed -i.lwbak '/\"directoryindex\"\ \:/ s/\:\ \"[a-zA-Z0-9\ \.]*\"/\:\ \"'"$remotehttpd_di"'\"/' /etc/cpanel/ea4/ea4.conf
		else
			sed -i.lwbak "s/\s*[\"\']\?directoryindex[\"\']\?\:\ [\"\']\?[a-zA-Z0-9\.\ ]\+[\"\']\?$/$remotehttpd_di/" /var/cpanel/conf/apache/main
		fi
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
		httpd -t 2>&1 | stderrlogit 4
		if [ "${PIPESTATUS[0]}" = "0" ]; then
			# config test was ok
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
			ec green "Success!"
		else
			# restart failed, revert
			ec red "Couldn't validate config after adjusting DirectoryIndex priority! Reverting changes..." | errorlogit 3
			mv -f /var/cpanel/conf/apache/main{.lwbak,}
			mv -f /etc/cpanel/ea4/ea4.conf{.lwbak,}
			/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
			/scripts/restartsrv_apache 2>&1 | stderrlogit 4
		fi
	fi

	# remoteip or rpaf
	if sssh "httpd -M 2>&1" | grep -q -E '(remoteip|rpaf)'_module ; then
		ec yellow "Apache remoteip or rpaf module detected! Installing mod_remoteip..."
		yum -y -q install ea-apache24-mod_remoteip 2>&1 | stderrlogit 4
	fi
}
