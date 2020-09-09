ea4phpextras () { #run after ea4 to match handler, default version, and variables
	# change default version
	if /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q $(echo $remotephp | cut -d. -f1-2 | tr -d '.'); then
		# remote php default available on target
		ec yellow "Matching default PHP version to $(echo $remotephp | cut -d. -f1-2)..."
		local newdefault=`/usr/local/cpanel/bin/rebuild_phpconf --available | grep $(echo $remotephp | cut -d. -f1-2 | tr -d '.') | cut -d: -f1`
		/usr/local/cpanel/bin/rebuild_phpconf --default $newdefault
	elif /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q ea-php73; then
		# php73 available on target
		ec yellow "Remote PHP version of $(echo $remotephp | cut -d. -f1-2) not available! Changing default to 7.3..."
		/usr/local/cpanel/bin/rebuild_phpconf --default ea-php73
	else
		# neither available on target
		ec red "Remote PHP version of $(echo $remotephp | cut -d. -f1-2) AND suggested default of 7.0 are not available! Leaving default php version at $(/usr/local/cpanel/bin/rebuild_phpconf --current | head -n1 | awk '{print $3}')"
	fi

	# phphandler
	defaultea4profile=`/usr/local/cpanel/bin/rebuild_phpconf --current | head -1 | awk '{print $3}'`
	if [ "$matchhandler" ]; then
		ec yellow "Matching php handler..."
		[ "$matchhandler" = "cgi" ] && yum -y -q install ea-apache24-mod_suexec 2>&1 | stderrlogit 4
		/usr/local/cpanel/bin/whmapi1 php_set_handler version=$defaultea4profile handler=$matchhandler
	fi
	# csf.pignore is handled by lw-csf-rules yum install during finish_up()

	# fcgi
	if [ $fcgiconvert ]; then
		installfpmrpms
	fi

	# find module mismatches
	ec yellow "Comparing module lists..."
	if [ $remoteea = "EA3" ]; then
		# collect single php version modules from source, using matching php version from target
		[ -d /opt/cpanel/ea-php$(echo $remotephp | cut -d. -f1-2 | tr -d .) ] && local phpbin="/opt/cpanel/ea-php$(echo $remotephp | cut -d. -f1-2 | tr -d .)/root/usr/bin/php" || local phpbin="$(which php)"
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

	# select localphpfile to compare php limits
	[ -f /opt/cpanel/${defaultea4profile}/root/etc/php.d/local.ini ] && localphpfile="/opt/cpanel/${defaultea4profile}/root/etc/php.d/local.ini" || localphpfile="/opt/cpanel/${defaultea4profile}/root/etc/php.ini"

	#set phpfile. use local.ini over php.ini for ea4, otherwise global php.ini
	if [ "$remoteea" = "EA3" ]; then
		phpfile=$dir/usr/local/lib/php.ini
	elif [ -f $dir/opt/cpanel/ea-php$(echo ${remotephp} | cut -d. -f1-2 | tr -d '.')/root/etc/php.d/local.ini ]; then
		phpfile=$dir/opt/cpanel/ea-php$(echo ${remotephp} | cut -d. -f1-2 | tr -d '.')/root/etc/php.d/local.ini
	elif [ -f $dir/opt/cpanel/ea-php$(echo ${remotephp} | cut -d. -f1-2 | tr -d '.')/root/etc/php.ini ]; then
		phpfile=$dir/opt/cpanel/ea-php$(echo ${remotephp} | cut -d. -f1-2 | tr -d '.')/root/etc/php.ini
	else
		unset phpfile
		ec red "Unable to select a remote php.ini file to copy limits from!" | errorlogit 3
	fi

	if [ "${phpfile}" -a "${localphpfile}" ]; then
		# only proceed if we were able to set both variables. compare php limits and set any larger remote values on php.ini for all local versions
		ec yellow "Setting limits from ${phpfile} (compared against $defaultea4profile limits)..."

		# memory limit
		remotephp_memory_limit=`sed -n 's/^memory_limit.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${phpfile}`
		localphp_memory_limit=`sed -n 's/^memory_limit.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${localphpfile}`
		if echo $remotephp_memory_limit | egrep -q '[0-9]+' && [ $(nonhuman $remotephp_memory_limit) -gt $(nonhuman $localphp_memory_limit) ]; then
			ec yellow " memory_limit ($localphp_memory_limit to $remotephp_memory_limit)"
			for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				[ -f /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
				sed -i "s/^\(memory_limit\ \?=\ \?\)[0-9]\+[A-Z]\?/\1$remotephp_memory_limit/" $file
				unset file
			done
		fi

		# max execution time
		remotephp_met=`sed -n 's/^max_execution_time.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${phpfile}`
		localphp_met=`sed -n 's/^max_execution_time.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${localphpfile}`
		if echo $remotephp_met | egrep -q '[0-9]' && [ $remotephp_met -gt $localphp_met ]; then
			ec yellow " max_execution_time ($localphp_met to $remotephp_met)"
			for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				[ -f /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
				sed -i "s/^\(max_execution_time\ \?=\ \?\)[0-9]\+[A-Z]\?/\1$remotephp_met/" $file
				unset file
			done
		fi

		# max input time
		remotephp_mit=`sed -n 's/^max_input_time.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${phpfile}`
		localphp_mit=`sed -n 's/^max_input_time.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${localphpfile}`
		if echo $remotephp_mit | egrep -q '[0-9]' && [ $remotephp_mit -gt $localphp_mit ]; then
			ec yellow " max_input_time ($localphp_mit to $remotephp_mit)"
			for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				[ -f /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
				sed -i "s/^\(max_input_time\ \?=\ \?\)[0-9]\+[A-Z]\?/\1$remotephp_mit/" $file
				unset file
			done
		fi

		# timezone
		remotephp_timezone=`sed -n 's/^date.timezone.*=\ \?\(.+\?\)/\1/p' ${phpfile}`
		localphp_timezone=`sed -n 's/^date.timezone.*=\ \?\(.+\?\)/\1/p' ${localphpfile}`
		if echo $remotephp_timezone | egrep -q '^(\"[A-Za-z\/\_]+\"|[A-Za-z\/\_]+)$'; then
			ec yellow " timezone ($localphp_timezone to $remotephp_timezone)"
			for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				[ -f /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
				sed -i "s/^\(date.timezone\ \?=\ \?\).*/\1$(echo ${remotephp_timezone} | sed -e 's/\//\\\//')/" $file
				unset file
			done
		fi

		# post max size
		remotephp_pms=`sed -n 's/^post_max_size.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${phpfile}`
		localphp_pms=`sed -n 's/^post_max_size.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${localphpfile}`
		if echo $remotephp_pms | egrep -q '[0-9]+' && [ $(nonhuman $remotephp_pms) -gt $(nonhuman $localphp_pms) ]; then
			ec yellow " post_max_size ($localphp_pms to $remotephp_pms)"
			for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				[ -f /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
				sed -i "s/^\(post_max_size\ \?=\ \?\)[0-9]\+[A-Z]\?/\1$remotephp_pms/" $file
				unset file
			done
		fi

		# upload max filesize
		remotephp_umf=`sed -n 's/^upload_max_filesize.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${phpfile}`
		localphp_umf=`sed -n 's/^upload_max_filesize.*=\ \?\([0-9]\+[A-Z]\?\).*/\1/p' ${localphpfile}`
		if echo $remotephp_umf | egrep -q '[0-9]+' && [ $(nonhuman $remotephp_umf) -gt $(nonhuman $localphp_umf) ]; then
			ec yellow " upload_max_filesize ($localphp_umf to $remotephp_umf)"
			for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
				[ -f /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
				sed -i "s/^\(upload_max_filesize\ \?=\ \?\)[0-9]\+[A-Z]\?/\1$remotephp_umf/" $file
				unset file
			done
		fi
	else
		ec red "Couldn't get the right ini files together to set php limits!" | errorlogit 3
	fi
}
