phpextras() { #run after ea4 to match handler, default version, and variables
	# change default version
	if /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q "$remotephp"; then
		# remote php default available on target
		ec yellow "Matching default PHP version to $remotephp..."
		/usr/local/cpanel/bin/rebuild_phpconf --default "$remotephp"
	elif /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q ea-php83; then
		# php83 available on target
		ec yellow "Remote PHP version of $remotephp not available! Changing default to 83..."
		/usr/local/cpanel/bin/rebuild_phpconf --default ea-php83
	else
		# neither available on target
		ec red "Remote PHP version of $remotephp AND suggested default of 83 are not available! Leaving default php version at $(/usr/local/cpanel/bin/rebuild_phpconf --current | head -n1 | awk '{print $3}')"
	fi
	defaultea4profile=$(/usr/local/cpanel/bin/rebuild_phpconf --current | head -1 | awk '{print $3}')

	# phphandler
	if [ "$matchhandler" ]; then
		ec yellow "Matching php handlers..."
		if [ "$remoteea" = "EA3" ]; then
			#only available ea3 handler versions were fcgi, suphp, dso, and cgi
			[[ "$remotephphandler" = "cgi" || "$remotephphandler" == "dso" ]] && yum -yq install ea-apache24-mod_suexec 2>&1 | stderrlogit 4
			#dso not available on new machines, set this to cgi, otherwise whatever was there is ok
			[ "$remotephphandler" = "dso" ] && sethandler="cgi" || sethandler=$remotephphandler
			for ver in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				whmapi1 php_set_handler version="$ver" handler="$sethandler" | stderrlogit 4
			done
		else #remote ea4, match every version individually
			while read -r ver; do
				if /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q "$ver"; then
					whmapi1 php_set_handler version="$ver" handler="$(sssh "/usr/local/cpanel/bin/rebuild_phpconf --current" | awk '/'"$ver"'/ {print $NF}')" | stderrlogit 4
				else
					ec red "$ver is missing on target server! Can't match its handler." | errorlogit 4 root
				fi
			done < <(sssh "/usr/local/cpanel/bin/rebuild_phpconf --available" | cut -d: -f1)
		fi
	fi

	# fpm
	installfpmrpms
	
	# compare php limits across versions; if a particular target version is not available on source, skip that version
	for ver in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
		unset phpfile localphpfile
		if [ "$remoteea" = "EA3" ] && [ -f "$dir/usr/local/lib/php.ini" ]; then
			phpfile="$dir/usr/local/lib/php.ini"
		elif [ -f "$dir/opt/cpanel/$ver/root/etc/php.d/local.ini" ]; then
			phpfile="$dir/opt/cpanel/$ver/root/etc/php.d/local.ini"
		elif [ -f "$dir/opt/cpanel/$ver/root/etc/php.ini" ]; then
			phpfile="$dir/opt/cpanel/$ver/root/etc/php.ini"
		fi

		if [ -f "/opt/cpanel/$ver/root/etc/php.d/local.ini" ]; then
			localphpfile="/opt/cpanel/$ver/root/etc/php.d/local.ini"
		elif [ -f "/opt/cpanel/$ver/root/etc/php.ini" ]; then
			localphpfile="/opt/cpanel/$ver/root/etc/php.ini"
		fi

		if [ "$phpfile" ] && [ "$localphpfile" ]; then
			ec yellow "Settings limits for $ver into $localphpfile from $phpfile..."
			cp -a "$localphpfile"{,.pullsyncbak}
			# number-based settings (0-9 with or without human-readable size suffix)
			for setting in memory_limit max_execution_time max_input_time max_input_vars post_max_size upload_max_filesize; do
				unset remotesetting localsetting
				remotesetting=$(sed -n 's/^'$setting'.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' "$phpfile")
				localsetting=$(sed -n 's/^'$setting'.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' "$localphpfile")
				if [ "$remotesetting" ] && [ "$localsetting" ] && echo "$remotesetting" | grep -Eq '[0-9]+' && [ "$(nonhuman "$remotesetting")" -gt "$(nonhuman "$localsetting")" ]; then
					ec yellow " $setting ($localsetting to $remotesetting)"
					sed -i "s/^\($setting\ \?=\ \?\)[0-9]\+[A-Z]\?/\1$remotesetting/" "$localphpfile"
				fi
			done
			# text-based settings and booleans (quoted or unquoted text string with or without / and _, OR 0 or 1)
			for setting in date.timezone disable_functions short_open_tag display_errors; do
				unset remotesetting localsetting
				remotesetting=$(sed -n 's/^'${setting}'.*=\ \?\(.+\?\)/\1/p' "$phpfile")
				localsetting=$(sed -n 's/^'${setting}'.*=\ \?\(.+\?\)/\1/p' "$localphpfile")
				if [ "$remotesetting" ] && [ "$localsetting" ] && echo "$remotesetting" | grep -Eq '^(\"[A-Za-z01\/\_]+\"|[A-Za-z01\/\_]+)$' && [ "$(echo "$remotesetting" | tr -d \")" != "$(echo "$localsetting" | tr -d \")" ]; then
					ec yellow " $setting ($localsetting to $remotesetting)"
					sed -i "s/^\($setting\ \?=\ \?\).*/\1$(echo "$remotesetting" | sed -e 's/\//\\\//g')/" "$localphpfile"
				fi
			done
			# error_reporting (unquoted text string with spaces, &, ~, ^, and _, OR a number)
			remoteerr=$(sed -n 's/^error_reporting.*=\ \?\(.+\?\)/\1/p' "$phpfile")
			localerr=$(sed -n 's/^error_reporting.*=\ \?\(.+\?\)/\1/p' "$localphpfile")
			if echo "$remoteerr" | grep -Eq '^([A-Z\_\ \&\~\^]+)$' && [ "$remoteerr" != "$localerr" ]; then
				ec yellow " error_reporting ($localerr to $remoteerr)"
				sed -i "s/^\(error_reporting\ \?=\ \?\).*/\1$(echo "$remoteerr" | sed -e 's/\&/\\\&/g' -e 's/\ /\\\ /g')/" "$localphpfile"
			fi
		else
			ec red "Unable to select a config file to compare and adjust php limits for $ver! It either wasn't installed on source or wasn't installed properly on target!" | errorlogit 3 root
		fi
	done
}
