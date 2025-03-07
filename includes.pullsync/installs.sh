installs() { # install all of the things we found and enabled
	local rhel homevariables cpupdate tweak_modules tweak_output tweak_backup tweak_exitcode source_ciphers target_ciphers upgradeid mysqlupstatus remoteinnodbstrict _t remotesqlmode modsecroot _localval _remoteval
	rhel=$(rpm --eval %rhel)

	# tweak
	if [ "$copytweak" ]; then
		ec yellow "$hg Copying tweak settings"
		# backup HOMEDIR or HOMEMATCH so we can reset it after
		homevariables=$(grep -e ^HOMEMATCH\  -e ^HOMEDIR\  /etc/wwwacct.conf)
		# backup update preferences
		cpupdate=$(cat /etc/cpupdate.conf)
		# check the available modules to execute the correct backup function
		tweak_modules=$(sssh "/usr/local/cpanel/bin/cpconftool --list-modules" | paste -sd' ')
		if [[ "$tweak_modules" == "cpanel::system::tweaksettings cpanel::smtp::exim" || "$tweak_modules" == "cpanel::smtp::exim cpanel::system::tweaksettings" ]]; then
			tweak_output=$(sssh "/usr/local/cpanel/bin/cpconftool --backup")
		elif grep -q cpanel::system::whmconf <<< "$tweak_modules"; then
			tweak_output=$(sssh "/usr/local/cpanel/bin/cpconftool --backup --modules=cpanel::smtp::exim,cpanel::system::whmconf")
		else
			ec red "Could not confirm expected modules will be restored! Aborting WHM tweak settings copy." | errorlogit 2 root
			ec red "Expected \"cpanel::system::tweaksettings cpanel::smtp::exim\" or \"cpanel::system::whmconf\""
			ec red "remote server reported \"$modules\"."
		fi
		# check the output of the backup to ensure success
		if grep -q 'Backup Successful' <<< "$tweak_output"; then
			tweak_backup=$(grep "tar.gz" <<< "$output")
			# copy over the backup
			srsync "$ip":"$tweak_backup" "$dir/"
			# combat tar timestamp errors from clock drift
			sleep 2
			if [ -f "$dir/whm-config-backup-all-original.tar.gz" ]; then
				# rsync was successful, restore command selection based on version
				if [ "$(cut -d. -f2 /usr/local/cpanel/version)" -ge 56 ]; then
					/usr/local/cpanel/bin/cpconftool --restore="$dir/$(cut -d/ -f3 <<< "$tweak_backup")" --modules=cpanel::smtp::exim,cpanel::system::whmconf &> "$dir/tweaksettings.log"
					tweak_exitcode=$?
				else
					/usr/local/cpanel/bin/cpconftool --restore="$dir/$(cut -d/ -f3 <<< "$tweak_backup")" &> "$dir/tweaksettings.log"
					tweak_exitcode=$?
				fi
				if [ "$tweak_exitcode" = "0" ]; then
					writecm
					# if custom exim filter, copy it over
					exim_filter="$(awk '/^system_filter / {print $3}' /etc/exim.conf)"
					if [ ! "$exim_filter" = "/etc/cpanel_exim_system_filter" ]; then
						srsync "$ip":"$eximfilter" "$eximfilter"
					fi
					# if blockeddomains, import
					[ -f "$dir/etc/blockeddomains" ] && cat "$dir/etc/blockeddomains" >> /etc/blockeddomains
					# if homedir or homematch changed, put them back
					sed -i -e '/^HOMEDIR\ /d' -e '/^HOMEMATCH\ /d' /etc/wwwacct.conf
					echo "$homevariables" >> /etc/wwwacct.conf
					# ensure that the correct ip is used for httpd listening
					if [ "$(grep -c port=0.0.0.0 /var/cpanel/cpanel.config)" -lt 2 ]; then
						ec red "Ports for apache in /var/cpanel/cpanel.config do not appear to be listening on 0.0.0.0!" | errorlogit 4 root
						grep _port= /var/cpanel/cpanel.config | logit
						ec yellow "$hg Resetting these to 0.0.0.0:80 and 0.0.0.0:443..."
						whmapi1 set_tweaksetting key=apache_port value=0.0.0.0:80 2>&1 | stderrlogit 3
						whmapi1 set_tweaksetting key=apache_ssl_port value=0.0.0.0:443 2>&1 | stderrlogit 3
						/scripts/restartsrv_apache 2>&1 | stderrlogit 3
						writecm
					fi
					# make sure we wont accidentally downgrade cpanel from current to lts/stable by restoring the update preferences
					echo "$cpupdate" > /etc/cpupdate.conf
				else
					writexx
					ec red "Restore of WHM tweak settings failed. See $dir/tweaksettings.log for details, and $dir/whm-config-backup-all-original.tar.gz for the original settings." | errorlogit 2 root
				fi
			else
				writexx
				ec red "Could not locate local backup of tweak settings! Aborting WHM tweak settings copy. Restore tweak settings manually with '/usr/local/cpanel/bin/cpconftool --restore=$dir/$(cut -d/ -f3 <<< "$tweak_backup") --modules=cpanel::smtp::exim,cpanel::system::whmconf'" | errorlogit 2 root
			fi
		else
			writexx
			ec red "Did not recieve output of sucessful remote WHM tweak config backup, got $tweak_output" | errorlogit 2 root
		fi

		ec yellow "Copying additional WHM settings..."
		mkdir "$dir/pre_whm_config_settings"
		if [ -d "$dir/var/cpanel/webtemplates/" ]; then # default pages
			ec yellow " web templates"
			mv /var/cpanel/webtemplates "$dir/pre_whm_config_settings/" 2>&1 | stderrlogit 3
			# shellcheck disable=SC2086
			rsync $rsyncargs "$dir/var/cpanel/webtemplates" /var/cpanel/
		fi
		if [ -d "$dir/var/cpanel/customizations/" ]; then # theme customizations
			ec yellow " theme customizations"
			mv /var/cpanel/customizations "$dir/pre_whm_config_settings/" 2>&1 | stderrlogit 3
			# shellcheck disable=SC2086
			rsync $rsyncargs "$dir/var/cpanel/customizations" /var/cpanel/
		fi
		if [ -f "$dir/var/cpanel/icontact_event_importance.json" ] && [ -f /var/cpanel/icontact_event_importance.json ]; then # contact prefs
			ec yellow " contact preferences"
			mv /var/cpanel/icontact_event_importance.json "$dir/pre_whm_config_settings/" 2>&1 | stderrlogit 3
			cp -a "$dir/var/cpanel/icontact_event_importance.json" /var/cpanel/
		elif [ -f "$dir/var/cpanel/iclevels.conf" ] && [ -f /var/cpanel/iclevels.conf ]; then
			ec yellow " contact preferences"
			mv /var/cpanel/iclevels.conf "$dir/pre_whm_config_settings/" 2>&1 | stderrlogit 3
			cp -a "$dir/var/cpanel/iclevels.conf" /var/cpanel/
		fi
		if [ -f "$dir/var/cpanel/greylist/enabled" ]; then # greylisting
			ec yellow " spam greylist"
			whmapi1 disable_cpgreylist 2>&1 | stderrlogit 3
			mv /var/cpanel/greylist "$dir/pre_whm_config_settings/" 2>&1 | stderrlogit 3
			# shellcheck disable=SC2086
			rsync $rsyncargs "$dir/var/cpanel/greylist" /var/cpanel/
			\rm -f /var/cpanel/greylist/enabled
			whmapi1 enable_cpgreylist 2>&1 | stderrlogit 3
			whmapi1 load_cpgreylist_config 2>&1 | stderrlogit 3
		fi
		if [ -f "$dir/var/cpanel/hulkd/enabled" ]; then # cphulk
			ec yellow "Copying cPhulkd IP lists..."
			whmapi1 disable_cphulk 2>&1 | stderrlogit 3
			mv /var/cpanel/hulkd "$dir/pre_whm_config_settings/" 2>&1 | stderrlogit 3
			# shellcheck disable=SC2086
			rsync $rsyncargs "$dir/var/cpanel/hulkd" /var/cpanel/
			\rm -f /var/cpanel/hulkd/enabled
			whmapi1 enable_cphulk 2>&1 | stderrlogit 3
			/usr/local/cpanel/etc/init/startcphulkd 2>&1 | stderrlogit 3
		fi
		if [ -f "$dir/etc/alwaysrelay" ]; then # exim relay
			ec yellow " exim relay"
			mv /etc/alwaysrelay "$dir/pre_whm_config_settings/" 2>&1 | stderrlogit 3
			cp -a "$dir/etc/alwaysrelay" /etc/
		fi
		if sssh "which dovecot &> /dev/null"; then # dovecot is the only available option in whm now, assume target has dovecot"
			source_ciphers=$(sssh "dovecot -a" | awk '/^ssl_cipher_list = / {print $3}')
			target_ciphers=$(dovecot -a | awk '/^ssl_cipher_list = / {print $3}')
			if [ "$(tr ':' '\n' <<< "$source_ciphers" | sort)" != "$(tr ':' '\n' <<< "$target_ciphers" | sort)" ]; then
				ec yellow " dovecot ciphers"
				/usr/local/cpanel/bin/set-tls-settings --cipher-suites="$source_ciphers" --restart dovecot 2>&1 | stderrlogit 3
			fi
		fi
		ec yellow " global docroot"
		cp -a /usr/local/cpanel/htdocs "$dir/pre_whm_config_settings/"
		srsync "$ip":/usr/local/cpanel/htdocs/ /usr/local/cpanel/htdocs/
		/scripts/restartsrv_cpsrvd 2>&1 | stderrlogit 3
		ec green "$cm Success!"
	fi

	# csf rules
	if [ "$csfimport" ]; then
		ec yellow "$hg Importing CSF allow and deny lists"
		# outline the imported lines in case they need to be removed
		{ echo -e "\n######## following lines imported from pullsync on $starttime\n"; cat "$dir/etc/csf/csf.allow"; echo -e "\n######## end pullsync import\n"; } >> /etc/csf/csf.allow
		{ echo -e "\n######## following lines imported from pullsync on $starttime\n"; cat "$dir/etc/csf/csf.deny"; echo -e "\n######## end pullsync import\n"; } >> /etc/csf/csf.deny
		csf -r 2>&1 | stderrlogit 4
		writecm
	fi

	# lfd emails
	if [ "$lfdemailsoff" ]; then
		ec yellow "$hg Turning off alerts from LFD"
		sed -i 's/^\(SENDMAIL = \)\".*\"$/\1"\/usr\/bin\/true"/' /etc/csf/csf.conf
		csf -ra 2>&1 | stderrlogit 4
		writecm
	fi

	# system timezone
	if [ "$matchtimezone" ]; then
		ec yellow "$hg Matching timezone"
		# move the timezone symlink out of the way
		mv /etc/localtime /etc/localtime.pullsync.bak
		if [ -f /etc/sysconfig/clock ]; then
			# if there is a clock file, copy it in
			mv /etc/sysconfig/clock /etc/sysconfig/clock.pullsync.bak
			cp -a "$dir/etc/sysconfig/clock" /etc/sysconfig/
		fi
		# link the correct new timezone
		ln -s "/usr/share/zoneinfo/$remotetimezonefile" /etc/localtime
		for srv in httpd rsyslog mysql crond; do
			# restart services if they are running
			[ "$(pgrep $srv)" ] && /scripts/restartsrv_${srv} 2>&1 | stderrlogit 3
		done
		[ "$(pgrep ntpd)" ] && service ntpd restart 2>&1 | stderrlogit 3
		# get the remote timezone to compare
		remote_tz_check=$(sssh "date +%z")
		if [ "$remote_tz_check" = "$(date +%z)" ]; then
			writecm
		else
			writexx
			ec red "Timezones still do not seem to match. Remote timezone is $remote_tz_check and local timezone is $(date +%z)." | errorlogit 3 root
		fi
	fi

	# mysqlup
	if [ "$upgrademysql" ]; then
		ec yellow "$hg Upgrading MySQL"
		# start the upgrade in the background
		upgradeid="$(/usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version="$remotemysql" | awk '/upgrade_id:/ {print $2}')"
		if [ ! "$upgradeid" ]; then
			# upgrade couldnt start
			writexx
			ec red "Couldn't initiate MySQL upgrade, didn't get an upgrade process id!" | errorlogit 2 root
		fi
		while true; do
			# check the status every few seconds
			sleep 8
			mysqlupstatus="$(/usr/local/cpanel/bin/whmapi1 background_mysql_upgrade_status upgrade_id="$upgradeid" | awk '/state:/ {print $2}')"
			case $mysqlupstatus in
				inprogress) :;;
				failed)	writexx
					ec red "MySQL upgrade failed! (less /var/cpanel/logs/${upgradeid})" | errorlogit 2 root
					break;;
				success) writecm
					sql upgrade &> /dev/null
					break;;
				*)	writexx
					ec red "I got unexpected output during MySQL upgrade: $mysqlupstatus. Counting that as a fail! (less /var/cpanel/logs/${upgradeid})" | errorlogit 2 root
					break;;
			esac
		done
	fi

	# mysql settings
	if [ "$match_sqlmode" ]; then
		ec yellow "$hg Matching sql_mode and innodb_strict_mode"
		[ -f /etc/my.cnf ] && cp -a /etc/my.cnf{,.syncbak}
		[ -f /usr/my.cnf ] && cp -a /usr/my.cnf{,.syncbak}
		# sqlmode
		remotesqlmode="$(sssh_sql -BNe "select @@sql_mode" 2> /dev/null)"
		if [ -f /usr/my.cnf ] && grep -iq ^sql_mode /usr/my.cnf; then
			# there is a /usr/my.cnf, and sql_mode is set there
			sed -i '/^sql_mode/s/^/#/' /usr/my.cnf
			echo "sql_mode=\"$remotesqlmode\"" >> /usr/my.cnf
		elif grep -iq ^sql_mode /etc/my.cnf; then
			# sql_mode is set in /etc/my.cnf
			sed -i 's/^sql_mode.*/sql_mode=\"'"$remotesqlmode"'\"/' /etc/my.cnf
		else
			# sql_mode wasnt found anywhere, just set it
			sed -i '/\[mysqld\]/a sql_mode=\"'"$remotesqlmode"'\"' /etc/my.cnf
		fi
		# innodb strict
		remoteinnodbstrict=$(sssh_sql -BNe "select @@innodb_strict_mode" 2> /dev/null)
		if [ -f /usr/my.cnf ] && grep -iq ^innodb_strict_mode /usr/my.cnf; then
			sed -i '/^innodb_strict_mode/s/^/#/' /usr/my.cnf
			echo "innodb_strict_mode=\"$remoteinnodbstrict\"" >> /usr/my.cnf
		elif grep -iq ^innodb_strict_mode /etc/my.cnf; then
			sed -i 's/^innodb_strict_mode.*/innodb_strict_mode=\"'"$remoteinnodbstrict"'\"/' /etc/my.cnf
		else
			sed -i '/\[mysqld\]/a innodb_strict_mode=\"'"$remoteinnodbstrict"'\"' /etc/my.cnf
		fi
		/scripts/restartsrv_mysql 2>&1 | stderrlogit 3
		# sleep until mysql is back, up to 30 seconds
		_t=6
		while [[ $_t -gt 0 ]]; do
			(( _t -= 1 ))
			sleep 5
			sql admin status &> /dev/null && break
			if [[ $_t -eq 0 ]]; then
				writexx
				ec lightRed "Mysql didnt come back, undoing..." | errorlogit 3 root
				if [ -f /usr/my.cnf.syncbak ] || [ -f /etc/my.cnf.syncbak ]; then
					[ -f /usr/my.cnf.syncbak ] && mv -f /usr/my.cnf{.syncbak,}
					[ -f /etc/my.cnf.syncbak ] && mv -f /etc/my.cnf{.syncbak,}
				else
					ec lightRed "Mysql didnt come back! And I cant find my.cnf.syncbak! AAAAH" | errorlogit 1 root
					exitcleanup
				fi
				/scripts/restartsrv_mysql 2>&1 | stderrlogit 3
				sleep 15
			fi
		done
		if [ "$(mysql -BNe 'show variables like "sql_mode"' | awk '{print $2}')" = "$remotesqlmode" ]; then
			# sql_mode variables match
			writecm
		else
			writexx
			ec lightRed "Local sql_mode does not match remote:" | errorlogit 3 root
			ec red "Local sql_mode:  $(mysql -BNe 'show variables like "sql_mode"' | awk '{print $2}')" | errorlogit 3 root
			ec red "Remote sql_mode: $remotesqlmode" | errorlogit 3 root
			ec lightRed "Please ensure this is corrected!" | errorlogit 3 root
			sleep 2
		fi
	fi

	# upcp
	if [ "$upcp" ]; then
		ec yellow "$hg Running Upcp"
		/scripts/upcp &> /dev/null
		writecm
	fi

	# java
	if [ "$java" ]; then
		ec yellow "$hg Installing Java"
		case $javaver in
			8) yum -y -q install java-1.8.0-openjdk 2>&1 | stderrlogit 4;;
			*) yum -y -q install "java-$javaver-openjdk" 2>&1 | stderrlogit 4;;
		esac
		if ! which java &> /dev/null; then
			writexx
			ec red "Java $javaver failed to install!" | errorlogit 3 root
			unset solr pdftk
		else
			writecm
		fi
	fi

	# cpanel solr
	if [ "$installcpanelsolr" ]; then
		ec yellow "$hg Installing Dovecot FTS (cPanel solr)"
		/usr/local/cpanel/scripts/install_dovecot_fts 2>&1 | stderrlogit 3
		writecm
	fi

	# postgres
	if [ "$postgres" ]; then
		if ! pgrep 'postgres|postmaster' &> /dev/null; then
			# only proceed if pgsql isnt running
		 	ec yellow "$hg Installing Postgresql"
			# backup old pgsql folder if it exists
			[ -d /var/lib/pgsql ] && cp -rp /var/lib/pgsql{,.bak."$starttime"}
			# open ports
			if which csf &> /dev/null; then
				sed -i '/^PORTS_cpanel/b; s/2087/2087,5432/g' /etc/csf/csf.conf
				csf -ra 2>&1 | stderrlogit 4
			elif which apf &> /dev/null; then
				sed -i 's/2087/2087,5432/g' /etc/apf/conf.apf
				(apf -r &> /dev/null &)
			fi
			# use expect to install since it asks for input
		 	expect -c "set timeout 3600
			spawn /scripts/installpostgres
			expect \"Are you certain that you wish to proceed?\"
			send \"yes\r\"
			expect eof" &> /dev/null
			# allow local passwordless connections
			if grep -qE "local.*all.*all.*ident" /var/lib/pgsql/data/pg_hba.conf; then
				sed -i 's/\(local.*all.*all.*\)ident/\1trust/' /var/lib/pgsql/data/pg_hba.conf
			else
				echo "local all all trust" >> /var/lib/pgsql/data/pg_hba.conf
			fi
			sleep 3
			# start pgsql and init
			/scripts/restartsrv_postgres 2>&1 | stderrlogit 3
			createdb postgres -U postgres &> /dev/null
			writecm
		else
			ec yellow "Detected postgres is installed and running already"
		fi
	fi

	# match mysql variables
	if [ "$matchmysqlvariables" ]; then
		ec yellow "Matching critical MySQL variables..."
		cp -a /etc/my.cnf{,.pullsync.variablechange.bak}
		# compare ibps, ibpi, toc, kbs, and mc and set in /etc/my.cnf if source is greater than target by commenting out old variable and adding a new line
		for _v in $sql_variables; do
			_localval=$(eval echo "\$local_sql_$v")
			_remoteval=$(eval echo "\$remote_sql_$v")
			if [[ "$_localval" && "$_remoteval" && "$_localval" -lt "$_remoteval" ]]; then
				ec yellow " $_v ($(human "$_localval") to $(human "$_remoteval"))"
				sed -i -e '/^'"$_v"'/s/^/#/' -e '/\[mysqld\]/a'"$_v"'='"$_remoteval" /etc/my.cnf
			fi
		done
		# restart mysql once at the end
		/scripts/restartsrv_mysql 2>&1 | stderrlogit 3
		sleep 2
		if ! sql admin status &> /dev/null; then
			# mysql not running, revert
			ec red "MySQL failed to restart, variable change failed! Bad my.cnf at /etc/my.cnf.pullsync.failedvariablechange. Reverting my.cnf..." | errorlogit 3 root
			cp -a /etc/my.cnf{,.pullsync.failedvariablechange}
			mv /etc/my.cnf{.pullsync.variablechange.bak,}
			/scripts/restartsrv_mysql 2>&1 | stderrlogit 3
		else
			ec green "$cm Success!"
		fi
	fi

	# ea4
	if [ "$ea" ]; then # run ea4
		ec yellow "$hg EA4"
		yum -yq --skip-broken install ea-profiles-cpanel ea-config-tools 2>&1 | stderrlogit 4
		/usr/local/bin/ea_current_to_profile --output=/etc/cpanel/ea4/profiles/custom/pullsync-backup.json 2>&1 | stderrlogit 3
		if [ "$defaultea4" ]; then
			# use the default profile
			ea_install_profile --install /etc/cpanel/ea4/profiles/cpanel/default.json 2>&1 | tee -a "$dir/ea4.profile.install.log"
			writecm
		elif [ ! -f /etc/cpanel/ea4/profiles/custom/migration.json ]; then
			writexx
			ec red "Couldn't find migration.json! Skipping EA4..." | errorlogit 2 root
		else
			# use the custom migrated profile
			ea_install_profile --install /etc/cpanel/ea4/profiles/custom/migration.json 2>&1 | tee -a "$dir/ea4.profile.install.log"
			writecm
		fi
	fi

	# tomcat
	if [ "$tomcat" ]; then
		ec yellow "$hg Installing Tomcat"
		yum -yq install ea-tomcat85 2>&1 | stderrlogit 4
		writecm
	fi

	# modsec
	if [ "$modsecimport" ]; then
		ec yellow "$hg Copying modsec2 whitelist"
		modsecroot="/etc/apache2/conf.d/modsec2"
		cp -a "$modsecroot"/whitelist.conf{,.pullsync.bak}
		# copy in the content of either modsec whitelist if either has size
		[ -s "$dir/usr/local/apache/conf/modsec2/whitelist.conf" ] && cat "$dir/usr/local/apache/conf/modsec2/whitelist.conf" >> "$modsecroot/whitelist.conf"
		[ -s "$dir/etc/apache2/conf.d/modsec2/whitelist.conf" ] && cat "$dir/etc/apache2/conf.d/modsec2/whitelist.conf" >> "$modsecroot/whitelist.conf"
		if [ ! -s "$modsecroot/whitelist.conf" ]; then
			writexx
			ec red "Neither EA3 or EA4 modsec2 whitelist from source had content!" | errorlogit 4 root
		else
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
			if [ ! "${PIPESTATUS[0]}" = "0" ]; then
				# apache restart failed because of some addition to the whitelist, revert
				writexx
				ec red "Couldn't restart apache! Reverting changes..." | errorlogit 3 root
				mv -f "$modsecroot"/whitelist.conf{.pullsync.bak,}
				/scripts/restartsrv_apache 2>&1 | stderrlogit 3
			fi
		fi
	fi

	# modremoteip/modcloudflare
	if [ "$modremoteip" ]; then
		ec yellow "$hg Installing mod_remoteip plugin with cloudflare support"
		yum -y -q install ea-apache24-mod_remoteip 2>&1 | stderrlogit 4
		echo "RemoteIPHeader CF-Connecting-IP" >> /etc/apache2/conf.modules.d/370_mod_remoteip.conf
		for cfip in $(curl -s https://www.cloudflare.com/ips-v4) $(curl -s https://www.cloudflare.com/ips-v6); do
			echo "RemoteIPTrustedProxy $cfip" >> /etc/apache2/conf.modules.d/370_mod_remoteip.conf
		done
		sed -i '/\"logformat_/ s/\"%h/\"%a/' /etc/cpanel/ea4/ea4.conf
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 4
		/scripts/restartsrv_apache 2>&1 | stderrlogit 4
		writecm
	fi

	# ffmpeg; install ffmpeg binary only
	if [ "$ffmpeg" ]; then
		ec yellow "$hg Installing FFMPEG"
		yum --enablerepo=epel -yq localinstall --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-"$rhel".noarch.rpm 2>&1 | stderrlogit 4
		yum -yq install ffmpeg ffmpeg-devel 2>&1 | stderrlogit 4
		writecm
	fi

	# imagick
	[ "$imagick" ] && ec yellow "Installing imagemagick in separate screen..." && screen -S imagick -dm bash -c "yum -yq install ImageMagick ImageMagick-devel pcre-devel &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
	/opt/cpanel/\$each/root/usr/bin/pecl uninstall imagick
	printf '\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install imagick
	list=\$(grep -E -Rl ^extension=[\\\"]?imagick.so[\\\"]?$ /opt/cpanel/\$each/root/etc/php.d/)
	count=\$(echo \"\$list\" | wc -l)
	if [ \$count -gt 1 ]; then
		for i in \$(echo \"\$list\" | sort | head -n\$((\$count - 1))); do
			sed -i '/imagick.so/ s/^/;/' \$i
		done
	fi
done"

	# apc; install extension via pecl
	[ "$apc" ] && ec yellow "Installing APC/APCu in separate screen..." && screen -S apc -dm bash -c "for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -e php4 -e php5); do
	printf '\\n\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install apcu-4.0.10 &&
	(/opt/cpanel/\$each/root/usr/bin/php -m | grep -q -x apcu || echo -e 'extension=\"apcu.so\"\\napcu.enabled = 1' > /opt/cpanel/\$each/root/etc/php.d/apcu.ini)
done
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -v -e php4 -e php5); do
	printf '\\n\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install apcu &&
	(/opt/cpanel/\$each/root/usr/bin/php -m | grep -q -x apcu || echo -e 'extension=\"apcu.so\"\\napcu.enabled = 1' > /opt/cpanel/\$each/root/etc/php.d/apcu.ini)
done"

	# sodium; install via epel and pecl
	[ "$sodium" ] && ec yellow "Installing PHP libsodium in a separate screen..." && screen -S sodium -dm bash -c "yum --enablerepo=epel -y install libsodium libsodium-devel && for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -v -e php5 -e php4 ); do /opt/cpanel/$each/root/usr/bin/pecl install libsodium; done; /scripts/restartsrv_apache_php_fpm"

	# solr; install via script and extensions via make
	[ "$solr" ] && ec yellow "Installing solr in separate screen..." && screen -S solr -dm bash -c "cd /usr/local/src &&
rm -rf /usr/local/src/solr-*
wget https://archive.apache.org/dist/lucene/solr/8.9.0/solr-8.9.0.tgz &&
tar -zvf solr-8.9.0.tgz &&
cd /usr/local/src/solr-8.9.0/bin/ &&
/install_solr_service.sh /usr/local/src/solr-8.9.0.tgz &&
systemctl enable solr &&
systemctl start solr &&
yum -y -q install libcurl-devel &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
	printf '\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install solr
done"

	# redis; install via epel and extensions via pecl
	[ "$redis" ] && ec yellow "Installing redis in separate screen..." && screen -S redis -dm bash -c "yum --enablerepo=epel -y install redis &&
service redis start &&
systemctl enable redis &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
	printf '\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install redis
done"

	# nodejs before elasticsearch, just in case
	if [ "$nodejs" ]; then
		ec yellow "Installing Node.js and npm, and global npm packages detected on source..."
		# setup node with yum
		yum -yq install ea4-nodejs gcc-c++ make 2>&1 | stderrlogit 4
		[ ! -e /usr/bin/node ] && ln -s "$(find /opt/cpanel/ -maxdepth 1 | grep nodejs)"/bin/node /usr/bin/
		[ ! -e /usr/bin/npm ] && ln -s "$(find /opt/cpanel/ -maxdepth 1 | grep nodejs)"/bin/npm /usr/bin/
		if node -v &> /dev/null; then
			writecm
			# install success, install npm packages one by one globally
			ec yellow "Installing global npm packages from source..."
			for each in $npmlist; do
				echo "$each" | logit
				npm install "$each" -g 2>&1 | stderrlogit 3
			done
		else
			writexx
			ec red "Install of node or npm failed!" | errorlogit 3 root
		fi
	fi

	# elasticsearch; install elasticsearch and nodejs, install elasticdump on both machines, dump on source, rsync datadir to target, load on target
	[ "$elasticsearch" ] && ec yellow "Installing elasticsearch in a separate screen..." && screen -S elasticsearch -d -m bash -c "echo '[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md' > /etc/yum.repos.d/elasticsearch.repo &&
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch &&
yum -y install elasticsearch ea4-nodejs &&
sed -i 's|\${ES_TMPDIR}|/var/lib/elasticsearch|g' /etc/elasticsearch/jvm.options &&
systemctl enable elasticsearch &&
systemctl start elasticsearch &&
echo \"elasticsearch:1\" >> /etc/chkserv.d/chkservd.conf &&
echo \"service[elasticsearch]=x,x,x,/bin/systemctl restart elasticsearch.service,elasticsearch,elasticsearch\" >> /etc/chkserv.d/elasticsearch &&
PATH=\$PATH:\$(find /opt/cpanel/ -maxdepth 1 | grep nodejs | head -1)/bin/ &&
npm install elasticdump -g &&
ssh ${sshargs} ${ip} \"[ -f /etc/cpanel/ea4/is_ea4 ] && yum -y install ea4-nodejs && PATH=\\\$(echo \\\$PATH:\\\$(find /opt/cpanel/ -maxdepth 1 | grep nodejs | head -1)/bin/) && npm install elasticdump -g && mkdir $remote_tempdir/elastic && multielasticdump --direction=dump --input=http://localhost:9200 --output=$remote_tempdir/elastic/\" &&
rsync $rsyncargs --bwlimit=$rsyncspeed -e \"ssh $sshargs\" $ip:$remote_tempdir/elastic $dir/ &&
multielasticdump --direction=load --input=$dir/elastic --output=http://localhost:9200"

	# wkhtmltopdf
	if [ "$wkhtmltopdf" ]; then
		ec yellow "$hg Installing wkhtmltopdf"
		if [ "$rhel" -le 7 ]; then
			yum -yq localinstall https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox-0.12.6-1.centos"$rhel".x86_64.rpm 2>&1 | stderrlogit 4
		else
			yum -yq localinstall https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-3/wkhtmltox-0.12.6-3.almalinux"$rhel".x86_64.rpm 2>&1 | stderrlogit 4
		fi
		writecm
	fi

	# pdftk
	if [ "$pdftk" ]; then
		ec yellow "$hg Installing pdftk"
		# rpm install per os major version
		if [ "$rhel" -eq 6 ]; then
			yum -yq localinstall https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk-2.02-1.el6.x86_64.rpm 2>&1 | stderrlogit 4
		else
			yum --enablerepo=epel -yq install pdftk-java 2>&1 | stderrlogit 4
		fi
		writecm
	fi

	# imunify (was maldet)
	if [ "$imunify" ]; then
		ec yellow "$hg Installing imunify-av"
		bash <(curl -s https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh) 2>&1 | stderrlogit 4
		yum -y -q install imunify-antivirus-cpanel 2>&1 | stderrlogit 4
		imunify-antivirus enable-plugin 2>&1 | stderrlogit 4
		imunify-antivirus config update '{"ADMIN_CONTACTS": {"enable_icontact_notifications": true}}' 2>&1 | stderrlogit 4
		writecm
	fi

	# spamassassin
	if [ "$spamassassin" ]; then
		ec yellow "$hg Enabling spamassassin and copying rules"
		# turn on spam checking tweaks
		whmapi1 set_tweaksetting key=skipspamassassin value=0 2>&1 | stderrlogit 3
		whmapi1 configureservice service=spamd enabled=1 monitored=1 2>&1 | stderrlogit 3
		# copy old spamassassin config
		mv /etc/mail/spamassassin/local.cf{,.pullsync.bak}
		cp -a "$dir/etc/mail/spamassassin/local.cf" /etc/mail/spamassassin/
		screen -S spamassassin_config -dm /scripts/update_spamassassin_config
		writecm
	fi

	# configserver plugins
	configserver_installs

	# pear
	ec yellow "Matching PEAR packages in separate screen..."
	# get a list of pear modules, install in screen
	sssh "pear list" | awk '/[0-9]+.[0-9]+/ {print $1}' | tr '\n' ' ' > "$dir/pearlist.txt"
	screen -S pearinstall -dm bash -c "for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do /opt/cpanel/\$each/root/usr/bin/pear install \$(cat $dir/pearlist.txt); done"

	# cpan
	ec yellow "Matching CPAN packages in separate screen..."
	# get a list of perl modules for remote and local server
	sssh "perl -we 'use ExtUtils::Installed;my \$inst = ExtUtils::Installed->new();my @modules = \$inst->modules();foreach \$module (@modules){print \$module . \"\\n\";}'" > "$dir/cpanlist.remote.txt"
	perl -we 'use ExtUtils::Installed;my $inst = ExtUtils::Installed->new();my @modules = $inst->modules();foreach $module (@modules){print $module . "\n";}' > "$dir/cpanlist.local.txt"
	# get the list of modules not yet on target
	comm -13 "$dir/cpanlist.local.txt" "$dir/cpanlist.remote.txt" | paste -sd' ' > "$dir/cpanlist.toinstall.txt"
	# set the timeout to 30s to ensure that any modules that are interactive installs will get defaults set
	if grep -q inactivity_timeout /usr/share/perl5/CPAN/Config.pm; then
		sed -i 's/\([ ]*'\''inactivity_timeout'\''\ =>\ q\[\).*/\130]\,/' /usr/share/perl5/CPAN/Config.pm
	else
		sed -i '/CPAN::Config/a \ \ '\''inactivity_timeout'\''\ =>\ q[30]\,' /usr/share/perl5/CPAN/Config.pm
	fi
	# execute the install
	screen -S cpaninstall -dm bash -c "export PERL_MM_USE_DEFAULT=1; cpan -i CPAN; cpan -T \$(cat $dir/cpanlist.toinstall.txt)"

	# ruby gems
	if [ "$rubymatch" ]; then
		# get a list of gems, and separately, a list of rails versions on source
		sssh "gem list" | awk '{print $1}' | sed -e '/rails/d' -e '/\*/d' > "$dir/gemlist.txt"
		sssh "gem list rails" | grep ^rails\  | sed -e 's/rails//' -e 's/[() ]//g' | tr ',' '\n' > "$dir/railslist.txt"
		if grep -q passenger "$dir/gemlist.txt"; then
			ec yellow "$hg Installing Passenger"
			sed -i '/passenger/d' "$dir/gemlist.txt"
			# switch to apache-based install for el9+
			if [ "$rhel" -ge 9 ]; then
				yum -yq install ea-apache24-mod-passenger 2>&1 | stderrlogit 4
			else
				yum -yq install ea-ruby24-mod_passenger 2>&1 | stderrlogit 4
			fi
			while read -r list; do
				/scripts/featuremod --feature passengerapps --value enable --list "$list"
			done < <(find /var/cpanel/features/ -type f -printf "%f\n" | grep -v disabled)
			writecm
		fi
		# install any rails versions first
		if [ -s "$dir/railslist.txt" ]; then
			ec yellow "$hg Installing rails"
			while read -r ver; do
				gem install rails -v "$ver" 2>&1 | stderrlogit 3
			done < "$dir/railslist.txt"
			writecm
		fi
		ec yellow "Matching ruby gems in separate screen..."
		# install remaining gems
		screen -S geminstall -dm bash -c "gem install $(paste -sd' ' "$dir/gemlist.txt") --silent"
	fi

	# exim26
	if [ "$eximon26" ]; then
		ec yellow "$hg Opening port 26 for exim"
		# add chkservd script
		echo "service[exim-26]=26,QUIT,220,/usr/local/cpanel/scripts/restartsrv_exim" > /etc/chkserv.d/exim-26
		# open ports
		if which csf &> /dev/null; then
			sed -i 's/\([",]25,\)/\126,/g' /etc/csf/csf.conf
			csf -ra 2>&1 | stderrlogit 4
		elif which apf &> /dev/null; then
			sed -i 's/25,/25,26,/g' /etc/apf/conf.apf
			(apf -r &> /dev/null &)
		fi
		cp -a /etc/chkserv.d/chkservd.conf{,.pullsync.bak}
		# change any existing exim-$port line to exim-26
		if grep -q "^exim-.*" /etc/chkserv.d/chkservd.conf; then
			sed -i 's/^exim-.*/exim-26\:1/g' /etc/chkserv.d/chkservd.conf
		else
			echo "exim-26:1" >> /etc/chkserv.d/chkservd.conf
		fi
		# change the ports in exim config and restart everything
		sed -i.pullsync.bak 's/^daemon_smtp_ports.*/daemon_smtp_ports\ =\ 25\ :\ 26\ :\ 465\ :\ 587/g' /etc/exim.conf
		/scripts/restartsrv_chkservd 2>&1 | stderrlogit 4
		/usr/local/cpanel/scripts/restartsrv_exim 2>&1 | stderrlogit 3
		writecm
	fi

	# loadwatch
	if [ "$install_loadwatch" ]; then
		ec yellow "$hg Installing loadwatch"
		# backup the crontab and remove old crons
		cp -a /var/spool/cron/root "$dir/original.root.crontab"
		sed -i '/loadwatch/s/^/#/g' /var/spool/cron/root #comment any old loadwatch crons, just in case
		# install loadwatch via yum
		yum -yq install loadwatch 2>&1 | stderrlogit 4
		writecm
	fi
	# mysql access hosts
	if [ "$copyaccesshosts" ]; then
		ec yellow "$hg Importing MySQL Access Hosts"
		cat "$dir/var/cpanel/mysqlaccesshosts" >> /var/cpanel/mysqlaccesshosts
		writecm
	fi

	# php settings matching (now that all pecl modules are installed)
	if [[ "$ea" || "$noeaextras" ]]; then
		phpextras
		apacheextras
	fi
}
