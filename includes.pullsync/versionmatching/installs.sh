installs() { # install all of the things we found and enabled
	# tweak
	if [ $copytweak ]; then
		ec yellow "Copying tweak settings, may take a minute..."
		# backup HOMEDIR or HOMEMATCH so we can reset it after
		local homevariables=$(grep -e ^HOMEMATCH\  -e ^HOMEDIR\  /etc/wwwacct.conf)
		# check the available modules to execute the correct backup function
		modules=`sssh "/usr/local/cpanel/bin/cpconftool --list-modules"`
		if [ "$(echo $modules)" = "cpanel::system::tweaksettings cpanel::smtp::exim" ] || [ "$(echo $modules)" = "cpanel::smtp::exim cpanel::system::tweaksettings" ]; then
			output=`sssh "/usr/local/cpanel/bin/cpconftool --backup"`
		elif [ "$(echo $modules | tr ' ' '\n' | grep cpanel::system::whmconf)" = "cpanel::system::whmconf" ] ; then
			output=`sssh "/usr/local/cpanel/bin/cpconftool --backup --modules=cpanel::smtp::exim,cpanel::system::whmconf"`
		else
			ec red "Could not confirm expected modules will be restored! Aborting WHM tweak settings copy." | errorlogit 2
			ec red "Expected \"cpanel::system::tweaksettings cpanel::smtp::exim\" or \"cpanel::system::whmconf\""
			ec red "remote server reported \"$modules\"."
		fi
		# check the output of the backup to ensure success
		if echo $output | grep -q 'Backup Successful'; then
			cpconfbackup=`echo $output |awk '{print $3}'`
			# copy over the backup
			rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:$cpconfbackup $dir/
			# combat tar timestamp errors from clock drift
			sleep 2
			if [ -f $dir/whm-config-backup-all-original.tar.gz ]; then
				# rsync was successful, restore command selection based on version
				if [ $(cat /usr/local/cpanel/version | cut -d. -f2) -ge 56 ]; then
					/usr/local/cpanel/bin/cpconftool --restore=$dir/$(echo $cpconfbackup | cut -d\/ -f3) --modules=cpanel::smtp::exim,cpanel::system::whmconf &> $dir/tweaksettings.log
					local backupexitcode2=$?
				else
					/usr/local/cpanel/bin/cpconftool --restore=$dir/$(echo $cpconfbackup | cut -d\/ -f3) &> $dir/tweaksettings.log
					local backupexitcode2=$?
				fi
				if [ "$backupexitcode2" = "0" ]; then
					ec green "Success!"
					# if custom exim filter, copy it over
					exim_filter="$(grep ^system_filter\  /etc/exim.conf | awk '{print $3}')"
					if [ ! "$exim_filter" = "/etc/cpanel_exim_system_filter" ]; then
						rsync $rsyncargs --bwlimit=$rsyncspeed $ip:$eximfilter $eximfilter
					fi
					# if blockeddomains, import
					[ -f $dir/etc/blockeddomains ] && cat $dir/etc/blockeddomains >> /etc/blockeddomains
					# if homedir or homematch changed, put them back
					sed -i -e '/^HOMEDIR\ /d' -e '/^HOMEMATCH\ /d' /etc/wwwacct.conf
					echo "$homevariables" >> /etc/wwwacct.conf
					# ensure that the correct ip is used for httpd listening
					if [ $(grep -c port=0.0.0.0 /var/cpanel/cpanel.config) -lt 2 ]; then
						ec red "Ports for apache in /var/cpanel/cpanel.config do not appear to be listening on 0.0.0.0!"
						grep _port= /var/cpanel/cpanel.config | logit
						ec yellow "Resetting these to 0.0.0.0:80 and 0.0.0.0:443..."
						whmapi1 set_tweaksetting key=apache_port value=0.0.0.0:80 2>&1 | stderrlogit 3
						whmapi1 set_tweaksetting key=apache_ssl_port value=0.0.0.0:443 2>&1 | stderrlogit 3
						/scripts/restartsrv_apache 2>&1 | stderrlogit 3
					fi
				else
					ec red "Restore of WHM tweak settings failed. See $dir/tweaksettings.log for details, and $dir/whm-config-backup-all-original.tar.gz for the original settings." | errorlogit 2
				fi
			else
				ec red "Could not locate local backup of tweak settings! Aborting WHM tweak settings copy. Restore tweak settings manually with '/usr/local/cpanel/bin/cpconftool --restore=$dir/$(echo $cpconfbackup | cut -d\/ -f3) --modules=cpanel::smtp::exim,cpanel::system::whmconf'" | errorlogit 2
			fi
		else
			ec red "Did not recieve output of sucessful remote WHM tweak config backup, got $output" | errorlogit 2
		fi

		ec yellow "Copying additional WHM settings..."
		mkdir $dir/pre_whm_config_settings
		if [ -d $dir/var/cpanel/webtemplates/ ]; then # default pages
			ec yellow " web templates"
			mv /var/cpanel/webtemplates $dir/pre_whm_config_settings/ 2>&1 | stderrlogit 3
			rsync $rsyncargs --bwlimit=$rsyncspeed $dir/var/cpanel/webtemplates /var/cpanel/
		fi
		if [ -d $dir/var/cpanel/customizations/ ]; then # theme customizations
			ec yellow " theme customizations"
			mv /var/cpanel/customizations $dir/pre_whm_config_settings/ 2>&1 | stderrlogit 3
			rsync $rsyncargs --bwlimit=$rsyncspeed $dir/var/cpanel/customizations /var/cpanel/
		fi
		if [ -f $dir/var/cpanel/icontact_event_importance.json -a -f /var/cpanel/icontact_event_importance.json ]; then # contact prefs
			ec yellow " contact preferences"
			mv /var/cpanel/icontact_event_importance.json $dir/pre_whm_config_settings/ 2>&1 | stderrlogit 3
			cp -a $dir/var/cpanel/icontact_event_importance.json /var/cpanel/
		elif [ -f $dir/var/cpanel/iclevels.conf -a -f /var/cpanel/iclevels.conf ]; then
			ec yellow " contact preferences"
			mv /var/cpanel/iclevels.conf $dir/pre_whm_config_settings/ 2>&1 | stderrlogit 3
			cp -a $dir/var/cpanel/iclevels.conf /var/cpanel/
		fi
		if [ -f $dir/var/cpanel/greylist/enabled ]; then # greylisting
			ec yellow " spam greylist"
			/usr/local/cpanel/bin/whmapi1 disable_cpgreylist 2>&1 | stderrlogit 3
			mv /var/cpanel/greylist $dir/pre_whm_config_settings/ 2>&1 | stderrlogit 3
			rsync $rsyncargs --bwlimit=$rsyncspeed $dir/var/cpanel/greylist /var/cpanel/
			rm -f /var/cpanel/greylist/enabled
			/usr/local/cpanel/bin/whmapi1 enable_cpgreylist 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 load_cpgreylist_config 2>&1 | stderrlogit 3
		fi
		if [ -f $dir/var/cpanel/hulkd/enabled ]; then # cphulk
			ec yellow "Copying cPhulkd IP lists..."
			/usr/local/cpanel/bin/whmapi1 disable_cphulk 2>&1 | stderrlogit 3
			mv /var/cpanel/hulkd $dir/pre_whm_config_settings/ 2>&1 | stderrlogit 3
			rsync $rsyncargs --bwlimit=$rsyncspeed $dir/var/cpanel/hulkd /var/cpanel/
			rm -f /var/cpanel/hulkd/enabled
			/usr/local/cpanel/bin/whmapi1 enable_cphulk 2>&1 | stderrlogit 3
			/usr/local/cpanel/etc/init/startcphulkd 2>&1 | stderrlogit 3
		fi
		if [ -f $dir/etc/alwaysrelay ]; then # exim relay
			ec yellow " exim relay"
			mv /etc/alwaysrelay $dir/pre_whm_config_settings/ 2>&1 | stderrlogit 3
			cp -a $dir/etc/alwaysrelay /etc/
		fi
		if [ "$(sssh "which dovecot 2> /dev/null")" ]; then # dovecot is the only available option in whm now, assume target has dovecot"
			local source_ciphers=$(sssh "dovecot -a | grep ^ssl_cipher_list\ =\ " | awk '{print $3}')
			local target_ciphers=$(dovecot -a | grep ^ssl_cipher_list\ =\  | awk '{print $3}')
			if [ "$(echo $source_ciphers | tr ':' '\n' | sort)" != "$(echo $target_ciphers | tr ':' '\n' | sort)" ]; then
				ec yellow " dovecot ciphers"
				/usr/local/cpanel/bin/set-tls-settings --cipher-suites=$source_ciphers --restart dovecot 2>&1 | stderrlogit 3
			fi
		fi
		ec yellow " global docroot"
		cp -a /usr/local/cpanel/htdocs $dir/pre_whm_config_settings/
		rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:/usr/local/cpanel/htdocs/ /usr/local/cpanel/htdocs/
		/scripts/restartsrv_cpsrvd 2>&1 | stderrlogit 3
	fi

	# csf rules
	if [ $csfimport ]; then
		ec yellow "Importing CSF whitelist..."
		# outline the imported lines in case they need to be removed
		{ echo -e "\n######## following lines imported from pullsync on $starttime\n"; cat $dir/etc/csf/csf.allow; echo -e "\n######## end pullsync import\n"; } >> /etc/csf/csf.allow
		{ echo -e "\n######## following lines imported from pullsync on $starttime\n"; cat $dir/etc/csf/csf.deny; echo -e "\n######## end pullsync import\n"; } >> /etc/csf/csf.deny
		csf -r 2>&1 | stderrlogit 4
	fi

	# lfd emails
	if [ $lfdemailsoff ]; then
		ec yellow "Turning off alerts from LFD..."
		# switch off any _ALERT line, and turn off select PT_USER lines
		sed -i "s/^\([A-Z_]\+ALERT\s*=\s*\)\".\+\"/\\1\"0\"/g" /etc/csf/csf.conf
		sed -i -e 's/\(PT_USERPROC = "\).*/\10"/' -e 's/\(PT_USERMEM = "\).*/\10"/' -e 's/\(PT_USERTIME = "\).*/\10"/' /etc/csf/csf.conf
		csf -ra 2>&1 | stderrlogit 4
	fi

	# system timezone
	if [ $matchtimezone ]; then
		ec yellow "Matching timezone..."
		# move the timezone symlink out of the way
		mv /etc/localtime /etc/localtime.pullsync.bak
		if [ -f /etc/sysconfig/clock ]; then
			# if there is a clock file, copy it in
			mv /etc/sysconfig/clock /etc/sysconfig/clock.pullsync.bak
			cp -a $dir/etc/sysconfig/clock /etc/sysconfig/
		fi
		# link the correct new timezone
		ln -s /usr/share/zoneinfo/${remotetimezonefile} /etc/localtime
		ec yellow "Restarting applications to get new timezone..."
		for srv in httpd rsyslog mysql crond; do
			# restart services if they are running
			[ "$(pgrep $srv)" ] && /scripts/restartsrv_${srv} 2>&1 | stderrlogit 3
		done
		[ "$(pgrep ntpd)" ] && service ntpd restart 2>&1 | stderrlogit 3
		# get the remote timezone to compare
		remote_tz_check=`sssh "date +%z"`
		if [ "$remote_tz_check" = "$(date +%z)" ]; then
			ec green "Success!"
		else
			ec red "Timezones still do not seem to match. Remote timezone is $remote_tz_check and local timezone is $(date +%z)." | errorlogit 3
		fi
	fi

	# mysqlup
	if [ $upgrademysql ]; then
		ec yellow "Upgrading MySQL..."
		# start the upgrade in the background
		upgradeid="$(/usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=$remotemysql | grep upgrade_id\: | awk '{print $2}')"
		if [ ! "$upgradeid" ]; then
			# upgrade couldnt start
			ec red "Couldn't initiate MySQL upgrade, didn't get an upgrade process id!" | errorlogit 2
		fi
		while true; do
			# check the status every few seconds
			sleep 8
			local mysqlupstatus="$(/usr/local/cpanel/bin/whmapi1 background_mysql_upgrade_status upgrade_id=${upgradeid} | grep state\: | awk '{print $2}')"
			case $mysqlupstatus in
				inprogress)	echo -n ".";;
				failed)		ec red "MySQL upgrade failed! (less /var/cpanel/logs/${upgradeid})" | errorlogit 2 && break;;
				success)	ec green "Success!" && mysql_upgrade &> /dev/null && break;;
				*)		ec red "I got unexpected output during MySQL upgrade: ${mysqlupstatus}. Counting that as a fail! (less /var/cpanel/logs/${upgradeid})" | errorlogit 2 && break;;
			esac
		done
	fi

	# mysql settings
	if [ $match_sqlmode ]; then
		ec yellow "Matching sql_mode and innodb_strict_mode..."
		# sqlmode
		remotesqlmode=$(sssh "mysql -BNe 'show variables like \"sql_mode\"'" | awk '{print $2}')
		if [ -f /usr/my.cnf ] && grep -iq ^sql_mode /usr/my.cnf; then
			# there is a /usr/my.cnf, and sql_mode is set there
			sed -i.syncbak '/^sql_mode/s/^/#/' /usr/my.cnf
			echo "sql_mode=\"$remotesqlmode\"" >> /usr/my.cnf
		elif grep -iq ^sql_mode /etc/my.cnf; then
			# sql_mode is set in /etc/my.cnf
			cp -a /etc/my.cnf{,.syncbak}
			sed -i 's/^sql_mode.*/sql_mode=\"'$remotesqlmode'\"/' /etc/my.cnf
		else
			# sql_mode wasnt found anywhere, just set it
			cp -a /etc/my.cnf{,.syncbak}
			sed -i '/\[mysqld\]/a sql_mode=\"'$remotesqlmode'\"' /etc/my.cnf
		fi
		# innodb strict
		remoteinnodbstrict=$(sssh "mysql -BNe 'show variables like \"innodb_strict_mode\"'" | awk '{print $2}')
		if [ -f /usr/my.cnf ] && grep -iq ^innodb_strict_mode /usr/my.cnf; then
			sed -i.syncbak '/^innodb_strict_mode/s/^/#/' /usr/my.cnf
			echo "innodb_strict_mode=\"$remoteinnodbstrict\"" >> /usr/my.cnf
		elif grep -iq ^innodb_strict_mode /etc/my.cnf; then
			[ ! -f /etc/my.cnf.syncbak ] && cp -a /etc/my.cnf{,.syncbak}
			sed -i 's/^innodb_strict_mode.*/innodb_strict_mode=\"'$remoteinnodbstrict'\"/' /etc/my.cnf
		else
			[ ! -f /etc/my.cnf.syncbak ] && cp -a /etc/my.cnf{,.syncbak}
			sed -i '/\[mysqld\]/a innodb_strict_mode=\"'$remoteinnodbstrict'\"' /etc/my.cnf
		fi
		/scripts/restartsrv_mysql 2>&1 | stderrlogit 3
		ec white "Waiting for mysql to come back, please be patient..."
		sleep 3
		# sleep until mysql is back
		while ! mysqladmin status 2> /dev/null; do sleep 1; done
		if [ "$(mysql -BNe 'show variables like "sql_mode"' | awk '{print $2}')" = "$remotesqlmode" ]; then
			# sql_mode variables match
			ec green "Success!"
		else
			# something didnt go right
			ec lightRed "Local sql_mode does not match remote:" | errorlogit 3
			ec red "Local sql_mode:  $(mysql -BNe 'show variables like "sql_mode"' | awk '{print $2}')" | errorlogit 3
			ec red "Remote sql_mode: $remotesqlmode" | errorlogit 3
			ec lightRed "Please ensure this is corrected!" | errorlogit 3
			sleep 2
		fi
	fi

	# upcp
	[ $upcp ] && ec yellow "Running Upcp..." && /scripts/upcp

	# java
	[ "$java" ] && ec yellow "Installing Java..." && yum -y -q install java-1.8.0-openjdk

	# cpanel solr
	if [ "$installcpanelsolr" ]; then
		ec yellow "Installing cPanels solr..."
		/usr/local/cpanel/scripts/install_dovecot_fts 2>&1 | stderrlogit 3
	fi

	# postgres
	if [ "$postgres" ]; then
		if [ ! $(pgrep postgres &> /dev/null) ]; then
			# only proceed if pgsql isnt running
		 	ec yellow "Installing Postgresql..."
			# backup old pgsql folder if it exists
			cp -rp /var/lib/pgsql{,.bak.$starttime}
			# open ports
			if [ $(which csf 2> /dev/null) ]; then
				sed -i '/^PORTS_cpanel/b; s/2087/2087,5432/g' /etc/csf/csf.conf
				csf -ra 2>&1 | stderrlogit 4
			fi
			if [ $(which apf 2> /dev/null) ]; then
				sed -i 's/2087/2087,5432/g' /etc/apf/conf.apf
				apf -r &> /dev/null &
			fi
			# use expect to install since it asks for input
		 	expect -c "set timeout 3600
			spawn /scripts/installpostgres
			expect \"Are you certain that you wish to proceed?\"
			send \"yes\r\"
			expect eof"
			# allow local passwordless connections
			if grep -q -E local.*all.*all.*ident /var/lib/pgsql/data/pg_hba.conf; then
				sed -i 's/\(local.*all.*all.*\)ident/\1trust/' /var/lib/pgsql/data/pg_hba.conf
			else
				echo "local all all trust" >> /var/lib/pgsql/data/pg_hba.conf
			fi
			sleep 3
			# start pgsql and init
			/scripts/restartsrv_postgres 2>&1 | stderrlogit 3
			createdb postgres -U postgres
		else
			ec yellow "Detected postgres is installed and running already"
		fi
	fi

	# match mysql variables
	if [ "$matchmysqlvariables" ]; then
		ec yellow "Matching critical MySQL variables..."
		cp -a /etc/my.cnf{,.pullsync.variablechange.bak}
		# compare ibps, ibpi, toc, kbs, and mc and set in /etc/my.cnf if source is greater than target by commenting out old variable and adding a new line
		[ $local_sql_ibps -lt $remote_sql_ibps ] && ec yellow " innodb_buffer_pool_size ($( human $local_sql_ibps) to $(human $remote_sql_ibps))" && sed -i -e '/^innodb_buffer_pool_size/s/^/#/' -e '/\[mysqld\]/a innodb_buffer_pool_size='$remote_sql_ibps /etc/my.cnf
		[ $local_sql_ibpi -lt $remote_sql_ibpi ] && ec yellow " innodb_buffer_pool_instances ($local_sql_ibpi to $remote_sql_ibpi)" && sed -i -e '/^innodb_buffer_pool_instances/s/^/#/' -e '/\[mysqld\]/a innodb_buffer_pool_instances='$remote_sql_ibpi /etc/my.cnf
		[ $local_sql_toc -lt $remote_sql_toc ] && ec yellow " table_open_cache ($local_sql_toc to $remote_sql_toc)" && sed -i -e '/^table_open_cache/s/^/#/' -e '/\[mysqld\]/a table_open_cache='$remote_sql_toc /etc/my.cnf
		[ $local_sql_kbs -lt $remote_sql_kbs ] && ec yellow " key_buffer_size ($(human $local_sql_kbs) to $(human $remote_sql_kbs))" && sed -i -e '/^key_buffer_size/s/^/#/' -e '/\[mysqld\]/a key_buffer_size='$remote_sql_kbs /etc/my.cnf
		[ $local_sql_mc -lt $remote_sql_mc ] && ec yellow " max_connections ($local_sql_mc to $remote_sql_mc)" && sed -i -e '/^max_connections/s/^/#/' -e '/\[mysqld\]/a max_connections='$remote_sql_mc /etc/my.cnf
		# restart mysql once at the end
		/scripts/restartsrv_mysql 2>&1 | stderrlogit 3
		sleep 2
		if [ ! "$(mysqladmin status 2> /dev/null)" ]; then
			# mysql not running, revert
			ec red "MySQL failed to restart, variable change failed! Bad my.cnf at /etc/my.cnf.pullsync.failedvariablechange. Reverting my.cnf..." | errorlogit 3
			cp -a /etc/my.cnf{,.pullsync.failedvariablechange}
			mv /etc/my.cnf{.pullsync.variablechange.bak,}
			/scripts/restartsrv_mysql
		else
			ec green "Success!"
		fi
	fi

	# ea4
	if [ "$ea" ]; then # run ea4
		ec yellow "Installing supporting functions for EA4..."
		yum -y -q install ea-profiles-cpanel ea-config-tools 2>&1 | stderrlogit 4
		ec yellow "Backing up current config..."
		/usr/local/bin/ea_current_to_profile --output=/etc/cpanel/ea4/profiles/custom/pullsync-backup.json 2>&1 | stderrlogit 3
		if [ $defaultea4 ]; then
			# use the default profile
			ea_install_profile --install /etc/cpanel/ea4/profiles/cpanel/default.json 2>&1 | tee -a $dir/ea4.profile.install.log
			localea=EA4
			ea4phpextras
			#apacheextras
		else
			if [ ! -f /etc/cpanel/ea4/profiles/custom/migration.json ]; then
				ec red "Couldn't find migration.json! Skipping EA4..." | errorlogit 2
			else
				# use the custom migrated profile
				ec yellow "Running EA4..."
				ea_install_profile --install /etc/cpanel/ea4/profiles/custom/migration.json 2>&1 | tee -a $dir/ea4.profile.install.log
				if [ `which php 2> /dev/null` ] ; then
					ec green "Success!"
					localea=EA4
					ea4phpextras
					#apacheextras
				else
					ec red "EA failed! (cant find php binary) Installing default profile... (less $dir/ea4.profile.install.log)" | errorlogit 2
					yum -y -q install ea-profiles-cpanel 2>&1 | stderrlogit 4
					ea_install_profile --install /etc/cpanel/ea4/profiles/cpanel/default.json
					ea4phpextras
					#apacheextras
				fi
			fi
		fi
	fi

	# non-ea php settings matching
	if [ $noeaextras ]; then
		# run the php extras and apache extras without running ea
		ea4phpextras
		#apacheextras
	fi

	# tomcat
	[ "$tomcat" ] && [ "$localea" = "EA4" ] && ec yellow "Installing Tomcat..." && yum -y -q install ea-tomcat85


	# modcloudflare
	[ "$modcloudflare" ] && ec yellow "Installing mod_cloudflare plugin..." && yum -y -q install lw-mod_cloudflare-cpanel.noarch 2>&1 | stderrlogit 4

	# ffmpeg; install ffmpeg-php via yum and php plugins via make
	[ "$ffmpeg" ] && ec yellow "Installing FFMPEG in separate screen..." && screen -S ffmpeg -d -m bash -c "yum -y -q --nogpgcheck localinstall https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$(grep ^VERSION_ID /etc/os-release | cut -d= -f2 | tr -d "\"").noarch.rpm && yum -y -q install ffmpeg ffmpeg-devel &&
[ -f /etc/cpanel/ea4/is_ea4 ] &&
cd /usr/local/src &&
git clone https://github.com/tony2001/ffmpeg-php.git &&
cd ffmpeg-php &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -v php7); do
	/opt/cpanel/\$each/root/usr/bin/phpize
	./configure --with-php-config=/opt/cpanel/\$each/root/usr/bin/php-config --enable-skip-gd-check &&
	make && make install &&
	(/opt/cpanel/\$each/root/usr/bin/php -m | grep -q ffmpeg || echo 'extension=ffmpeg.so' >> /opt/cpanel/\$each/root/etc/php.d/20-ffmpeg.ini)
	make clean
done"

	# imagick
	[ "$imagick" ] && ec yellow "Installing imagemagick in separate screen..." && screen -S imagick -d -m bash -c "yum -y -q install ImageMagick ImageMagick-devel pcre-devel &&
[ -f /etc/cpanel/ea4/is_ea4 ] &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -v php7); do
	printf '\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install imagick
	list=\$(grep -E -Rl ^extension=[\\\"]?imagick.so[\\\"]?$ /opt/cpanel/\$each/root/etc/php.d/)
	count=\$(echo \"\$list\" | wc -l)
	if [ \$count -gt 1 ]; then
	for i in \$(echo \"\$list\" | sort | head -n\$((\$count - 1))); do
		sed -i '/imagick.so/ s/^/;/' \$i
	done
	fi
done &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
	/opt/cpanel/\$each/root/usr/bin/phpize &&
	./configure --with-php-config=/opt/cpanel/\$each/root/usr/bin/php-config &&
	make && make install &&
	(/opt/cpanel/\$each/root/usr/bin/php -m | grep -q magickwand || echo 'extension=magickwand.so' >> /opt/cpanel/\$each/root/etc/php.d/20-magickwand.ini)
	make clean
done"

	# apc; install extension via pecl
	[ "$apc" ] && ec yellow "Installing APC/APCu in separate screen..." && screen -S apc -d -m bash -c "for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -v php7); do
	printf '\\n\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install apcu-4.0.10 &&
	(/opt/cpanel/\$each/root/usr/bin/php -m | grep -q -x apcu || echo -e 'extension=\"apcu.so\"\\napcu.enabled = 1' > /opt/cpanel/\$each/root/etc/php.d/apcu.ini)
done
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep php7); do
	printf '\\n\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install apcu &&
	(/opt/cpanel/\$each/root/usr/bin/php -m | grep -q -x apcu || echo -e 'extension=\"apcu.so\"\\napcu.enabled = 1' > /opt/cpanel/\$each/root/etc/php.d/apcu.ini)
done"

	# sodium; install via epel and pecl
	[ "$sodium" ] && ec yellow "Installing PHP libsodium in a separate screen..." && screen -S sodium -d -m bash -c "yum -y install epel-release && yum --enablerepo=epel -y install libsodium libsodium-devel && for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -v php5 ); do /opt/cpanel/$each/root/usr/bin/pecl install libsodium; done; /scripts/restartsrv_apache_php_fpm"

	# solr
	[ "$solr" ] && ec yellow "Installing solr in separate screen..." && screen -S solr -d -m bash -c "cd /usr/local/src &&
rm -rf /usr/local/src/solr-*
wget https://archive.apache.org/dist/lucene/solr/6.6.0/solr-6.6.0.tgz &&
tar -xvf solr-6.6.0.tgz &&
cd /usr/local/src/solr-6.6.0/bin/ &&
./install_solr_service.sh /usr/local/src/solr-6.6.0.tgz &&
service solr start &&
systemctl enable solr &&
[ -f /etc/cpanel/ea4/is_ea4 ] &&
yum -y -q install libcurl-devel &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
	printf '\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install solr
done
[ ! -f /etc/cpanel/ea4/is_ea4 ] && pecl install solr"

	# redis; install via epel and extensions via pecl
	[ "$redis" ] && ec yellow "Installing redis in separate screen..." && screen -S redis -d -m bash -c "yum -y install epel-release &&
yum --enablerepo=epel -y install redis &&
service redis start &&
systemctl enable redis &&
[ -f /etc/cpanel/ea4/is_ea4 ] &&
for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
	printf '\\n' | /opt/cpanel/\$each/root/usr/bin/pecl install redis &&
done
[ ! -f /etc/cpanel/ea4/is_ea4 ] && pecl install redis"

	# elasticsearch; install elasticsearch and nodejs10, install elasticdump on both machines, dump on source, rsync datadir to target, load on target
	[ "$elasticsearch" ] && ec yellow "Installing elasticsearch in a separate screen..." && screen -S elasticsearch -d -m bash -c "echo '[elasticsearch]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md' > /etc/yum.repos.d/elasticsearch.repo &&
yum -y install elasticsearch ea-nodejs10 &&
sed -i 's|\${ES_TMPDIR}|/var/lib/elasticsearch|g' /etc/elasticsearch/jvm.options &&
systemctl enable elasticsearch &&
systemctl start elasticsearch &&
echo \"elasticsearch:1\" >> /etc/chkserv.d/chkservd.conf &&
echo \"service[elasticsearch]=x,x,x,/bin/systemctl restart elasticsearch.service,elasticsearch,elasticsearch\" >> /etc/chkserv.d/elasticsearch &&
PATH=\$PATH:/opt/cpanel/ea-nodejs10/bin/ &&
npm install elasticdump -g &&
ssh ${sshargs} ${ip} \"[ -f /etc/cpanel/ea4/is_ea4 ] && PATH=\\\$(echo \\\$PATH:/opt/cpanel/ea-nodejs10/bin/) && yum -y install ea-nodejs10 && npm install elasticdump -g && mkdir $remote_tempdir/elastic && multielasticdump --direction=dump --input=http://localhost:9200 --output=$remote_tempdir/elastic/\" &&
rsync $rsyncargs --bwlimit=$rsyncspeed -e \"ssh $sshargs\" $ip:$remote_tempdir/elastic $dir/ &&
multielasticdump --direction=load --input=$dir/elastic --output=http://localhost:9200"

	# wkhtmltopdf
	[ "$wkhtmltopdf" ] && ec yellow "Installing wkhtmltopdf..." && yum -y -q localinstall https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox-0.12.6-1.centos$(grep ^VERSION_ID /etc/os-release | cut -d= -f2 | tr -d "\"").x86_64.rpm

	# pdftk
	if [ "$pdftk" ]; then
		ec yellow "Installing pdftk..."
		# rpm install per os major version
		if [ $(echo $local_os | tr -d '[a-zA-Z() ]' | cut -d. -f1) -eq 7 ]; then
			yum -y localinstall https://www.linuxglobal.com/static/blog/pdftk-2.02-1.el7.x86_64.rpm 2>&1 | stderrlogit 4
		elif [ $(echo $local_os | tr -d '[a-zA-Z() ]' | cut -d. -f1) -eq 6 ]; then
			yum -y localinstall https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk-2.02-1.el6.x86_64.rpm 2>&1 | stderrlogit 4
		else
			ec red "Couldnt detect your OS major version for pdftk install!" | errorlogit 3
		fi
	fi

	# maldet
	if [ "$maldet" ]; then
		ec yellow "Installing maldet..."
		rm -rf /usr/local/src/maldetect-*
		rm -rf /usr/local/src/linux-malware-detect*
		pushd /usr/local/src/ 2>&1 | stderrlogit 4
		# download and run install script
		wget -q http://www.rfxn.com/downloads/maldetect-current.tar.gz
		tar -zxf maldetect-current.tar.gz
		cd maldetect-*
		sh ./install.sh 2>&1 | stderrlogit 3
		popd 2>&1 | stderrlogit 4
		# if bin is missing, try symlink first
		[ ! "$(which maldet 2> /dev/null)" ] && ln -s /usr/local/sbin/maldet /usr/local/bin/
		if [ "$(which maldet 2> /dev/null)" ]; then
			# install success, continue with config
			maldet --update-ver 2>&1 | stderrlogit 3
			# adjust config
			sed -i -e 's/quarantine_hits=\"1\"/quarantine_hits=\"0\"/' -e 's/quarantine_clean=\"1\"/quarantine_clean=\"0\"/' -e 's/email_alert=\"1\"/email_alert=\"0\"/' -e 's/email_addr=\"you@domain.com\"/email_addr=\"\"/' /usr/local/maldetect/conf.maldet
			maldet --update 2>&1 | stderrlogit 3
			if [ -e /usr/local/cpanel/3rdparty/bin/clamscan ]; then
				# link cpanel clamscan binaries
				ln -s /usr/local/cpanel/3rdparty/bin/clamscan /usr/bin/clamscan
				ln -s /usr/local/cpanel/3rdparty/bin/freshclam /usr/bin/freshclam
				[ ! -d /var/lib/clamav ] && mkdir /var/lib/clamav
				ln -s /usr/local/cpanel/3rdparty/share/clamav/main.cld /var/lib/clamav/main.cld
				ln -s /usr/local/cpanel/3rdparty/share/clamav/daily.cld /var/lib/clamav/daily.cld
				ln -s /usr/local/cpanel/3rdparty/share/clamav/bytecode.cld /var/lib/clamav/bytecode.cld
			fi
			# correct homedir scan in cron
			sed -i 's/home?/hom?/g' /etc/cron.daily/maldet
			ec green "Success!"
		else
			ec red "Install of maldet failed!" | errorlogit 3
		fi
	fi

	# spamassassin
	if [ $spamassassin ]; then
		ec yellow "Enabling spamassassin and copying rules..."
		# turn on spam checking tweaks
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=skipspamassassin value=0 2>&1 | stderrlogit 3
		/usr/local/cpanel/bin/whmapi1 configureservice service=spamd enabled=1 monitored=1 2>&1 | stderrlogit 3
		# copy old spamassassin config
		mv /etc/mail/spamassassin/local.cf{,.pullsync.bak}
		cp -a $dir/etc/mail/spamassassin/local.cf /etc/mail/spamassassin/
		screen -S spamassassin_config -d -m /scripts/update_spamassassin_config
	fi

	# configserver plugins
	configserver_installs

	# pear
	ec yellow "Matching PEAR packages in separate screen..."
	# get a list of pear modules, install in screen
	sssh "pear list" | egrep [0-9]{1}.[0-9]{1} | awk '{print $1}' | tr '\n' ' ' > $dir/pearlist.txt
	screen -S pearinstall -d -m bash -c "if [ -f /etc/cpanel/ea4/is_ea4 ]; then for each in \$(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do /opt/cpanel/\$each/root/usr/bin/pear install \$(cat $dir/pearlist.txt); done; else; pear install \$(cat $dir/pearlist.txt); fi"

	# cpan
	ec yellow "Matching CPAN packages in separate screen..."
	# get a list of perl modules for remote and local server
	sssh "perl -w -e 'use ExtUtils::Installed;my \$inst = ExtUtils::Installed->new();my @modules = \$inst->modules();foreach \$module (@modules){print \$module . \"\\n\";}'" > $dir/cpanlist.remote.txt
	perl -w -e 'use ExtUtils::Installed;my $inst = ExtUtils::Installed->new();my @modules = $inst->modules();foreach $module (@modules){print $module . "\n";}' > $dir/cpanlist.local.txt
	# get the list of modules not yet on target
	cat $dir/cpanlist.remote.txt | grep -vx -f $dir/cpanlist.local.txt | tr '\n' ' ' > $dir/cpanlist.toinstall.txt
	# set the timeout to 30s to ensure that any modules that are interactive installs will get defaults set
	grep -q inactivity_timeout /usr/share/perl5/CPAN/Config.pm && sed -i 's/\([ ]*'\''inactivity_timeout'\''\ =>\ q\[\).*/\130]\,/' /usr/share/perl5/CPAN/Config.pm || sed -i '/CPAN::Config/a \ \ '\''inactivity_timeout'\''\ =>\ q[30]\,' /usr/share/perl5/CPAN/Config.pm
	# execute the install
	screen -S cpaninstall -d -m bash -c "export PERL_MM_USE_DEFAULT=1; cpan -i CPAN; cpan -T \$(cat $dir/cpanlist.toinstall.txt)"

	# ruby gems
	if [ "$rubymatch" ]; then
		# get a list of gems, and separately, a list of rails versions on source
		sssh "gem list" | awk '{print $1}' | sed -e '/rails/d' -e '/\*/d' > $dir/gemlist.txt
		sssh "gem list rails" | grep ^rails\  | sed -e 's/rails//' -e 's/[() ]//g' | tr ',' '\n' > $dir/railslist.txt
		if grep -q passenger $dir/gemlist.txt; then
			# install passenger per ea version
			ec yellow "Passenger gem detected on source, installing separately..."
			sed -i '/passenger/d' $dir/gemlist.txt
			if [ "$localea" = "EA4" ]; then
				yum -y -q install ea-ruby24-mod_passenger 2>&1 | stderrlogit 4
				/bin/ls -A /var/cpanel/features/ | while read list; do
					/scripts/featuremod --feature passengerapps --value enable --list "$list"
				done
			fi
		fi
		# install any rails versions first
		[ -s $dir/railslist.txt ] && ec yellow "Installing rails separately..." && for ver in `cat $dir/railslist.txt`; do gem install rails -v $ver 2>&1 | stderrlogit 3; done
		ec yellow "Matching ruby gems in separate screen..."
		# install remaining gems
		screen -S geminstall -d -m gem install $(cat $dir/gemlist.txt | tr '\n' ' ') --silent
	fi

	# exim26
	if [ $eximon26 ]; then
		ec yellow "Opening port 26 for exim..."
		# add chkservd script
		echo "service[exim-26]=26,QUIT,220,/usr/local/cpanel/scripts/restartsrv_exim" > /etc/chkserv.d/exim-26
		# open ports
		if [ `which csf 2> /dev/null` ]; then
			sed -i 's/\([",]25,\)/\126,/g' /etc/csf/csf.conf
			csf -ra 2>&1 | stderrlogit 4
		elif [ `which apf 2> /dev/null` ]; then
			sed -i 's/25,/25,26,/g' /etc/apf/conf.apf
			apf -r &> /dev/null &
		fi
		cp -a /etc/chkserv.d/chkservd.conf{,.pullsync.bak}
		# change any existing exim-$port line to exim-26
		if grep -q ^exim-.* /etc/chkserv.d/chkservd.conf; then
			sed -i 's/^exim-.*/exim-26\:1/g' /etc/chkserv.d/chkservd.conf
		else
			echo "exim-26:1" >> /etc/chkserv.d/chkservd.conf
		fi
		# change the ports in exim config and restart everything
		sed -i.pullsync.bak 's/^daemon_smtp_ports.*/daemon_smtp_ports\ =\ 25\ :\ 26\ :\ 465\ :\ 587/g' /etc/exim.conf
		/scripts/restartsrv_chkservd 2>&1 | stderrlogit 4
		/usr/local/cpanel/scripts/restartsrv_exim 2>&1 | stderrlogit 3
	fi

	# nodejs
	if [ $nodejs ]; then
		ec yellow "Installing Node.js and npm, and global npm packages detected on source..."
		# setup node 4.x with yum
		curl --silent --location https://rpm.nodesource.com/setup_4.x | bash - 2>&1 | stderrlogit 3
		yum -q -y install nodejs npm gcc-c++ make 2>&1 | stderrlogit 4
		if [ `which node 2> /dev/null` ]; then
			# install success, install npm packages one by one globally
			for each in $npmlist; do
				echo $each | logit
				npm install $each -g 2>&1 | stderrlogit 3
			done
		else
			ec red "Install of node or npm failed!" | errorlogit 3
		fi
	fi

	# loadwatch
	if [ ${install_loadwatch} ]; then
		ec yellow "Installing loadwatch..."
		# backup the crontab and remove old crons
		cp -a /var/spool/cron/root ${dir}/original.root.crontab
		sed -i '/loadwatch/s/^/#/g' /var/spool/cron/root #comment any old loadwatch crons, just in case
		# install loadwatch via yum
		yum -y -q install loadwatch 2>&1 | stderrlogit 4
	fi
	# mysql access hosts
	if [ ${copyaccesshosts} ]; then
		ec yellow "Importing MySQL Access Hosts..."
		cat ${dir}/var/cpanel/mysqlaccesshosts >> /var/cpanel/mysqlaccesshosts
	fi
}
