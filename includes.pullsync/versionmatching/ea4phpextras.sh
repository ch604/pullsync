ea4phpextras() { #run after ea4 to match handler, default version, and variables
	niceremotephp=$(echo $remotephp | cut -d. -f1-2 | tr -d '.')
	# change default version
	if /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q $niceremotephp; then
		# remote php default available on target
		ec yellow "Matching default PHP version to $niceremotephp..."
		local newdefault=`/usr/local/cpanel/bin/rebuild_phpconf --available | grep $niceremotephp | cut -d: -f1`
		/usr/local/cpanel/bin/rebuild_phpconf --default $newdefault
	elif /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q ea-php81; then
		# php81 available on target
		ec yellow "Remote PHP version of $niceremotephp not available! Changing default to 81..."
		/usr/local/cpanel/bin/rebuild_phpconf --default ea-php81
	else
		# neither available on target
		ec red "Remote PHP version of $niceremotephp AND suggested default of 81 are not available! Leaving default php version at $(/usr/local/cpanel/bin/rebuild_phpconf --current | head -n1 | awk '{print $3}')"
	fi
	defaultea4profile=$(/usr/local/cpanel/bin/rebuild_phpconf --current | head -1 | awk '{print $3}')

	# phphandler
	if [ "$matchhandler" ]; then
		ec yellow "Matching php handlers..."
		if [ $remoteea = "EA3" ]; then
			#only available ea3 handler versions were fcgi, suphp, dso, and cgi
			[ "$remotephphandler" = "cgi" ] && yum -y -q install ea-apache24-mod_suexec 2>&1 | stderrlogit 4
			#dso not available on new machines, set this to cgi, otherwise whatever was there is ok
			[ "$remotephphandler" = "dso" ] && sethandler="cgi" || sethandler=$remotephphandler
			for ver in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				/usr/local/cpanel/bin/whmapi1 php_set_handler version=$ver handler=$sethandler | stderrlogit 4
			done
		else #remote ea4, match every version individually
			for ver in $(sssh "/usr/local/cpanel/bin/rebuild_phpconf --available" | cut -d: -f1); do
				/usr/local/cpanel/bin/rebuild_phpconf --available | grep -q $ver && /usr/local/cpanel/bin/whmapi1 php_set_handler version=$ver handler=$(sssh "/usr/local/cpanel/bin/rebuild_phpconf --current"  awk '/'$ver'/ {print $NF}') | stderrlogit 4 || ec red "$ver is missing on target server! Can't match its handler." | errorlogit 4
			done
		fi
	fi

	# fpm
	installfpmrpms
	
	# find module mismatches
	ec yellow "Comparing module lists..."
	if [ $remoteea = "EA3" ]; then
		# collect single php version modules from source, using matching php version from target
		[ -f /opt/cpanel/ea-php${niceremotephp}/enable ] && local phpbin="/opt/cpanel/ea-php${niceremotephp}/root/usr/bin/php" || local phpbin="$(which php)"
		# list out modules
		local target_modules=$(eval $phpbin -m 2> /dev/null | grep -v -e ^$ -e "\[" -e "(" | tr '\n' '|' | sed -e 's/|$//' -e 's/\ /\\\ /g')
		local missing_modules=$(sssh "php -m 2> /dev/null" | egrep -v -e "^($target_modules)$" -e ^$ -e "\[" -e "\(")
		if [ "$missing_modules" ]; then
			# items remain in variable after egrep -v
			ec red "PHP modules are missing from the target that were installed on source! (cat $dir/missing_php_modules.txt)" | errorlogit 2
			echo $missing_modules | tee -a $dir/missing_php_modules.txt
			echo "evaluated using $phpbin" | tee -a $dir/missing_php_modules.txt
			ec red "If you are matching versions, you should address this after the sync!"
		else
			ec green "No modules found on source that were not installed on target already."
		fi
	else
		# remote server using ea4. collect modules for all versions.
		for ver in $(sssh "/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1"); do
			if [ -d /opt/cpanel/$ver ]; then
				# same version is installed on target
				local target_modules=$(/opt/cpanel/$ver/root/usr/bin/php -m 2> /dev/null | grep -v -e ^$ -e "\[" -e "(" | tr '\n' '|' | sed -e 's/|$//' -e 's/\ /\\\ /g')
				local missing_modules=$(sssh "/opt/cpanel/$ver/root/usr/bin/php -m 2> /dev/null" | egrep -v -e "^($target_modules)$" -e ^$ -e "\[" -e "\(")
				if [ "$missing_modules" ]; then
					echo $missing_modules >> $dir/missing_php_modules.txt
					echo "evaluated using /opt/cpanel/$ver/root/usr/bin/php" >> $dir/missing_php_modules.txt
				fi
			fi
		done
		if [ -s $dir/missing_php_modules.txt ]; then
			# file has size and therefore missing modules were found
			ec red "PHP modules are missing from the target that were installed on source! (cat $dir/missing_php_modules.txt)" | errorlogit 2
			cat $dir/missing_php_modules.txt
			ec red "If you are matching versions, you should address this after the sync!"
		fi
	fi

	# compare php limits across versions; if a particular target version is not available on source, skip that version
	for ver in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
		unset phpfile localphpfile
		if [ "$remoteea" = "EA3" ] && [ -f $dir/usr/local/lib/php.ini ]; then
			phpfile=$dir/usr/local/lib/php.ini
		elif echo $phplimitvers | grep -q $ver; then
			if [ -f $dir/opt/cpanel/$ver/root/etc/php.d/local.ini ]; then
				phpfile=$dir/opt/cpanel/$ver/root/etc/php.d/local.ini
			elif [ -f $dir/opt/cpanel/$ver/root/etc/php.ini ]; then
				phpfile=$dir/opt/cpanel/$ver/root/etc/php.ini
			fi
		fi

		if [ -f /opt/cpanel/$ver/root/etc/php.d/local.ini ]; then
			localphpfile=/opt/cpanel/$ver/root/etc/php.d/local.ini
		elif [ -f /opt/cpanel/$ver/root/etc/php.ini ]; then
			localphpfile=/opt/cpanel/$ver/root/etc/php.ini
		fi

		if [ "${phpfile}" -a "${localphpfile}" ]; then
			ec yellow "Settings limits for $ver into $localphpfile from $phpfile..."
			cp -a $localphpfile{,.pullsyncbak}
			# number-based settings (0-9 with or without human-readable size suffix)
			for setting in memory_limit max_execution_time max_input_time max_input_vars post_max_size upload_max_filesize; do
				unset remotesetting localsetting
				remotesetting=$(sed -n 's/^'${setting}'.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' $phpfile)
				localsetting=$(sed -n 's/^'${setting}'.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' $localphpfile)
				if echo $remotesetting | egrep -q '[0-9]+' && [ $(nonhuman $remotesetting) -gt $(nonhuman $localsetting) ]; then
					ec yellow " $setting ($localsetting to $remotesetting)"
					sed -i "s/^\("${setting}"\ \?=\ \?\)[0-9]\+[A-Z]\?/\1"${remotesetting}"/" $localphpfile
				fi
			done
			# text-based settings and booleans (quoted or unquoted text string with or without / and _, OR 0 or 1)
			for setting in date.timezone disable_functions short_open_tag display_errors; do
				unset remotesetting localsetting
				remotesetting=$(sed -n 's/^'${setting}'.*=\ \?\(.+\?\)/\1/p' $phpfile)
				localsetting=$(sed -n 's/^'${setting}'.*=\ \?\(.+\?\)/\1/p' $localphpfile)
				if echo $remotesetting | egrep -q '^(\"[A-Za-z01\/\_]+\"|[A-Za-z01\/\_]+)$' && [ "$(echo $remotesetting | tr -d \")" != "$(echo $localsetting | tr -d \")" ]; then
					ec yellow " $setting ($localsetting to $remotesetting)"
					sed -i "s/^\("${setting}"\ \?=\ \?\).*/\1$(echo $remotesetting | sed -e 's/\//\\\//g')/" $localphpfile
				fi
			done
			# error_reporting (unquoted text string with spaces, &, ~, ^, and _, OR a number)
			remoteerr=$(sed -n 's/^error_reporting.*=\ \?\(.+\?\)/\1/p' $phpfile)
			localerr=$(sed -n 's/^error_reporting.*=\ \?\(.+\?\)/\1/p' $localphpfile)
			if echo $remoteerr | egrep -q '^([A-Z\_\ \&\~\^]+)$' && [ "$remoteerr" != "$localerr" ]; then
				ec yellow " error_reporting ($localerr to $remoteerr)"
				sed -i "s/^\(error_reporting\ \?=\ \?\).*/\1$(echo $remoteerr | sed -e 's/\&/\\\&/g' -e 's/\ /\\\ /g')/" $localphpfile
			fi
		else
			ec red "Unable to select a config file to compare php limits for $ver! That seems real bad!" | errorlogit 3
		fi
	done
}
