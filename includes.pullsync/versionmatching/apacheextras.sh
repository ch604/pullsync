apacheextras() { #run after successful ea, copies extra apache things not part of ea
	if [ -f $dir/var/cpanel/conf/apache/local ]; then
		# there are apache setting includes from the old server, set them up and rebuild httpd
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
	remotehttp_di=$(grep -E [\"\']?directoryindex[\"\']?\:\ [\"\']?[a-zA-Z0-9] $dir/var/cpanel/conf/apache/main | tail -1)
	if [ "$remotehttpd_di" ]; then
		# if set, its nonstandard, set on local server
		ec yellow "Copying DirectoryIndex priority..."
		sed -i.pullsync.bak "s/\s*[\"\']\?directoryindex[\"\']\?\:\ [\"\']\?[a-zA-Z0-9\.\ ]\+[\"\']\?$/$remotehttpd_di/" /var/cpanel/conf/apache/main
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
		httpd -t 2>&1 | stderrlogit 4
		if [ "${PIPESTATUS[0]}" = "0" ]; then
			# config test was ok
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
			ec green "Success!"
		else
			# restart failed, revert
			ec red "Couldn't validate config after adjusting DirectoryIndex priority! Reverting changes..." | errorlogit 3
			mv -f /var/cpanel/conf/apache/main{.pullsync.bak,}
			/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
			/scripts/restartsrv_apache 2>&1 | stderrlogit 4
		fi
	fi
	if sssh "httpd -M 2>&1" | grep -q -E '(remoteip|rpaf)'_module ; then
		# if remoteip or rpaf
		ec yellow "Apache remoteip or rpaf module detected! Installing mod_remoteip..."
		yum -y -q install ea-apache24-mod_remoteip 2>&1 | stderrlogit 4
	fi
}
