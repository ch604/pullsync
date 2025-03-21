initialsync_main() { #the meaty heart of pullsync. performs the pre and post migration tasks for initially syncing accounts, including calling version matching menus and commands and cleanup and post-sync commands. this houses the breaking point between the attended and unattended sections.
	local phpbin target_modules missing_modules malware_accts malware_file_count

	# version matching menu stanza
	if echo -e "list\ndomainlist\nall" | grep -qx $synctype; then #no single or skeletons
		ec lightGreen "Here is what we found to install:"
		for prog in $proglist; do
			#see if $prog is set and echo it for version matching
			[ "${!prog}" ] && echo "$prog" | logit
		done
		# version matching menus
		if [ ! "$autopilot" ] ; then
			check_existing_users #warn if users exist
			if yesNo "Run version matching?"; then
				do_installs=1
				matching_menu
				phpmenu
				do_optimize=1
				optimize_menu
				security_menu
			elif yesNo "Would you like to just do the optimization and security menus instead?"; then
				do_optimize=1
				optimize_menu
				security_menu
			fi
		elif [ "$autopilot" ] && [ $do_installs ]; then
			# abort if users exist on autopilot
			check_existing_users
			# match CONTACTEMAIL
			[ ! -f $dir/whmcontact.txt ] && awk '/^CONTACTEMAIL / {print $2}' $dir/etc/wwwacct.conf > $dir/whmcontact.txt
			# do safe things and fuzzy matching
			rubymatch=1
			copytweak=1
			match_sqlmode=1
			if [ -e /etc/csf/csf.allow ]; then
				lfdemailsoff=1
				if [ -e $dir/etc/csf/csf.allow ]; then
					csfimport=1
				fi
			fi
			autophpmenu
			timezone_check
			[ -d /var/lib/pgsql ] && unset postgres
			[ ! -s /etc/apache2/conf.d/modsec2/whitelist.conf ] && [[ -s $dir/usr/local/apache/conf/modsec2/whitelist.conf || -s $dir/etc/apache2/conf.d/modsec2/whitelist.conf ]] && modsecimport=1
			do_optimize=1
			optimize_auto
			security_auto
		fi
		# bring over whm packages and features
		srsync -RL $ip:/var/cpanel/packages :/var/cpanel/features /var/cpanel/ 2>/dev/null
	fi

	# optional items menu, run for all synctypes
	if [ "$autopilot" ]; then
		optional_items_auto
	else
		optional_items_menu
	fi

	# final sync time guesser
	ec yellow "Selecting a good time for a final sync for you, this might take a minute..."
	synchour=$(parallel -j3 "parallel_besttime {}" ::: $userlist | cut -d: -f1 | awk -F'|' '{sum[$2]+=$1} END{for (hour in sum) printf("%.2d %.0f\n", hour, sum[hour])}' | sort -n -k2 | awk 'NR==1 {print $1}')

	# print ticket note
	ec lightPurple "Copy the following into your ticket:"
	(
	echo "started $scriptname $version at $starttime on $(hostname) ($cpanel_main_ip)"
	echo "synctype is $synctype. source server is $ip."
	echo "to reattach, run (screen -r $STY)."
	if  [ "$ded_ip_check" = "1" ] || [ "$single_dedip" = "yes" ]; then echo restored accounts to dedicated IPs; else echo restored accounts to main shared IP; fi
	[ "$comment_crons" ] && echo commented all restored users crons
	if [ $do_installs ]; then
		echo -e "\nperformed installs:"
		[ $copytweak ] && echo "* copied tweak settings"
		[ $setcontact ] && echo "* set whm contact email address"
		[ $csfimport ] && echo "* copied csf whitelist"
		[ $lfdemailsoff ] && echo "* turned off emails from lfd"
		[ $matchtimezone ] && echo "* set timezone to ${remotetimezone}"
		[ $copyaccesshosts ] && echo "* copied mysql access hosts list"
		[ $upcp ] && echo "* ran upcp"
		[ $upgrademysql ] && echo "* upgraded mysql"
		[ $rubymatch ] && echo "* matched ruby gems"
		[ "$java" ] && echo "* installed java $javaver"
		[ "$tomcat" ] && echo "* installed ea-tomcat85"
		[ "$postgres" ] && echo "* installed postgresql"
		[ "$includeschanges" ] && echo "* replaced files in /usr/local/apache/conf/includes/"
		[ "$modremoteip" ] && echo "* installed mod_remoteip (with cloudflare support)"
		[ "$match_sqlmode" ] && echo "* matched sql_mode and innodb_strict_mode"
		[ "$ea" ] && echo "* ran easyapache"
		[ $matchhandler ] && echo "* matched php handlers"
		[ $fpmconvert ] && echo "* converted arriving accounts to fpm"
		[ "$ffmpeg" ] && echo "* installed ffmpeg"
		[ "$imagick" ] && echo "* installed imagemagick and imagick"
		[ "$memcache" ] && echo "* installed memcached-full"
		[ "$apc" ] && echo "* installed apc/apcu"
		[ "$sodium" ] && echo "* installed sodium"
		[ "$imunify" ] && echo "* installed imunify-av"
		[ "$spamassassin" ] && echo "* enabled spamassassin"
		[ "$nodejs" ] && echo "* installed node.js and npm"
		[ "$wkhtmltopdf" ] && echo "* installed wkhtmltopdf"
		[ "$pdftk" ] && echo "* installed pdftk"
		[ "$redis" ] && echo "* installed redis and php plugins"
		[ "$elasticsearch" ] && echo "* installed elasticsearch and copied indexes"
		[ "$solr" ] && echo "* installed solr8 and php plugins"
		[ "$installcpanelsolr" ] && echo "* installed cpanels solr"
		[ "$matchmysqlvariables" ] && echo "* matched critical mysql variables"
		[ "$cmc" ] || [ "$cmm" ] || [ "$cmq" ] || [ "$cse" ] || [ "$mailscanner" ] && echo "* installed configserver plugins"
		[ "$modsecimport" ] && echo "* imported modsec2/whitelist.conf"
		[ $eximon26 ] && echo "* added exim-26"
		[ $cloudlinuxconfig ] && echo "* copied cloudlinux settings"
		[ $enabledbackups ] && echo "* turned on cpanel backups"
	else
		echo -e "\ndid not match versions"
	fi
	if [ $do_optimize ]; then
		echo -e "\nperformed server optimizations:"
		[ $modhttp2 ] && echo "* installed mod_http2"
		[ $memcache ] && echo "* installed memcache and its php connectors"
		[ $fpmdefault ] && echo "* set all sites to use php-fpm"
		[ $basicoptimize ] && echo "* turned on keepalive, mod_deflate, and mod_expires"
		[ $security_tweaks ] && echo "* turned on security tweaks"
		[ $pagespeed ] && echo "* installed mod_pagespeed"
		[ $do_mysqlcalc ] && echo "* calculated best ibps/kbs for mysql"
		echo -e "\nadded server security:"
		[ $enable_modevasive ] && echo "* enabled mod_evasive"
		[ $enable_modreqtimeout ] && echo "* enabled mod_reqtimeout"
		[ $disable_moduserdir ] && echo "* disabled mod_userdir globally"
	else
		echo -e "\ndid not perform server optimizations or security installs"
	fi
	[ $rcubesqlite ] && echo -e "\nconverted source roundcube storage to sqlite"
	[ $malwarescan ] && echo -e "\nscanned php files for malware during sync"
	[ $fixperms ] && echo -e "\nran fixperms on all docroots"
	[ $runmarill ] && echo -e "\nran marill auto-tests after sync"
	[ $initsyncwpt ] && echo -e "\nchecked operation of sites with WPT during sync"
	[ $dns_url ] && echo -e "\nuploaded DNS details to ${dns_url}"
	if [ "$(echo $userlist | wc -w)" -gt 15 ]; then
		echo -e "\ntruncated userlist ($(echo $userlist | wc -w)): $(echo $userlist | tr ' ' '\n' | head -15 | paste -sd' ')"
	else
		echo -e "\nuserlist ($(echo $userlist | wc -w)): $(echo $userlist | paste -sd' ')"
	fi
	echo ""
	[[ $synchour =~ [0-9]+ ]] && echo "I guessed at a final sync time for you based on domlog activity. The hour with the least traffic is $(printf "%02d" "${synchour#0}")00 $(sssh "date +%z")."
	) | tee -a $dir/ticketnote.txt | logit # end subshell for tee to ticketnote
	ec lightPurple "Stop copying now :D"
	ec green "Ready to do the initial sync!"
	say_ok

	# THIS IS THE START OF THE UNATTENDED SECTION
	handsoffepoch=$(date +%s)
	[ $addmotd ] && echo "Migration initial sync has been run with pullsync, and is awaiting a final sync" >> /etc/motd
	lastpullsyncmotd

	# backup cpanel settings before starting
	cpconfbackup

	# installs here
	[ $do_installs ] && installs
	[ $do_optimize ] && optimizations && install_security
	if [ $rcubesqlite ]; then
		ec yellow "Converting rcube mysql to sqlite on source..."
		sssh "/scripts/convert_roundcube_mysql2sqlite &> /dev/null"
		ec yellow "Converting rcube mysql to sqlite on target..."
		/scripts/convert_roundcube_mysql2sqlite &> /dev/null
	fi

	getreadyforparallel

	# null the whm email to avoid pestering the customer
	pausecontact

	# align certain settings to permit restores
	ec yellow "Adjusting some cPanel tweak settings..."
	/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=allowparkhostnamedomainsubdomains value=1 2>&1 | stderrlogit 3 #restore hostname-based domains
	/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=allowremotedomains value=1 2>&1 | stderrlogit 3 #restore domains that resolve elsewhere (duh)
	/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=nobodyspam value=0 2>&1 | stderrlogit 3 #allow 'nobody' to send mail
	/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=selfsigned_generation_for_bestavailable_ssl_install value=1 2>&1 | stderrlogit 3 #Self-Signed SSL generated for all new cPanel accounts
	[ -f /etc/csf/csf.conf ] && sed -i 's/^SMTP_BLOCK.*/SMTP_BLOCK = "0"/' /etc/csf/csf.conf && csf -ra 2>&1 | stderrlogit 3 #disable smtp block
	/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=publichtmlsubsonly value=0 2>&1 | stderrlogit 3 #dont restrict docroots to pubhtml
	ps axc | grep -q queueprocd || /scripts/restartsrv_queueprocd 2>&1 | stderrlogit 3 #ensure cpanel can queue processes for restore

	# OK HERE IS WHERE THE MAGIC HAPPENS! DONT BLINK!
	package_accounts
	# DONE. next few stanzas perform actions that are better done when all migrated users are done restoring.

	# sync unowned databases
	if [ "$syncunowneddbs" ] && [ -f /root/db_include.txt ]; then
		ec yellow "Syncing /root/db_include.txt..."
		dblist_restore=$(cat /root/db_include.txt)
		sanitize_dblist
		echo "$dblist_restore" > $dir/dblist.txt
		while read -r -u9 db; do
			mysql_dbsync "$db"
		done 9<$dir/dblist.txt
	fi

	# copy symlinks from /var/www/vhosts
	if [ "$(sssh "[ -d /var/www/vhosts ]")" ] && [ "$(sssh "find /var/www/vhosts/ -mindepth 1 -maxdepth 1 ! -type l" | wc -l)" -eq 0 ]; then
		# /var/www/vhosts on source contains only symlinks, or is empty
		ec yellow "Copying symlinks from /var/www/vhosts..."
		srsync -l $ip:/var/www/vhosts /var/www/
		# remove any broken symlinks in this directory, e.g. account was not copied to target. this will not affect any directories, files, or working symlinks. just in case, output to the error log:
		echo "Copied symlinks from /var/www/vhosts and deleted the following dangling symlinks:" | errorlogit 3 root
		find /var/www/vhosts/ -mindepth 1 -maxdepth 1 -type l ! -exec test -e {} \; -print -delete | errorlogit 3 root
	fi

	# check for items that were expected but did not restore
	ec yellow "Checking for unrestored items..."
	parallel -j 100% 'parallel_unrestored {}' ::: $userlist
	# if there are missing or misrestored items, error
	[ -f $dir/missingthings.txt ] && ec red "Things are missing! Counted $(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $dir/missingthings.txt | grep -c ^Domain) domains, $(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $dir/missingthings.txt | grep -c ^Database) databases, and $(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $dir/missingthings.txt | grep -c ^User) users incorrectly restored! (cat $dir/missingthings.txt)" | errorlogit 2 root

	# if backups were turned on, finish turning them on by enabling all users
	if [ "$enabledbackups" ]; then
		ec yellow "Finishing configuration of cPanel backups..."
		parallel -j 100% -u 'cpbackup_finish {}' ::: $userlist
	fi

	# if there are any resellers, ensure assignment
	if [ -s $dir/resellers.txt ]; then
		ec yellow "Ensuring all accounts are owned by their correct resellers..."
		while read -r -u8 reseller; do
			while read -r each; do
				/usr/local/cpanel/bin/whmapi1 modifyacct user=$each owner=$reseller 2>&1 | stderrlogit 3
			done < <(awk -F": |==" '$3=="'$reseller'" {print $2}' /etc/userdatadomains | sort -u | grep -vx $reseller)
		done 8<$dir/resellers.txt
	fi

	# if tomcat was installed or exists, restart tomcat instances
	[ -f /usr/local/cpanel/scripts/ea-tomcat85 ] && ec yellow "Restarting tomcat instances..." && /usr/local/cpanel/scripts/ea-tomcat85 all restart &> /dev/null

	# check to see if any mailman lists were copied and do some fixes to ensure operability
	mailmanfolderlist=$(find /usr/local/cpanel/3rdparty/mailman/lists/ -maxdepth 1 -mindepth 1 -type d)
	if [ "$mailmanfolderlist" ] && ! echo "$mailmanfolderlist" | grep -q \/mailman$; then
		#"mailman" mailing list does not exist, copy from source and enable
		ec yellow "Syncing over default mailman list and enabling mailman..."
		rsync $rsyncargs --bwlimit=$rsyncspeed -e "ssh $sshargs" $ip:/usr/local/cpanel/3rdparty/mailman/lists/mailman /usr/local/cpanel/3rdparty/mailman/lists/
		mkdir -p /usr/local/cpanel/3rdparty/mailman/qfiles/out
		/usr/local/cpanel/bin/whmapi1 configureservice service=mailman enabled=1 monitored=1 2>&1 | stderrlogit 3
		/scripts/fixmailman &> /dev/null
		service mailman restart &> /dev/null
	fi

	# set up cloudlinux things
	[ $cloudlinuxconfig ] && copy_cloudlinux_configs

	# enable fpm by converting all accounts
	if [ $fpmdefault ]; then
		ec yellow "Completing setup of FPM by default (changing all sites to use FPM)..."
		/usr/local/cpanel/bin/whmapi1 convert_all_domains_to_fpm
	fi

	# change x3 themes to paper_lantern
	if [ "$(cut -d. -f2 /usr/local/cpanel/version)" -ge "60" ]; then
		ec yellow "Correcting themes for 11.60+ compatibility..."
		# shellcheck disable=SC2016
		parallel -j 100% -u '[[ "$(/usr/local/cpanel/bin/whmapi1 accountsummary user={} | grep theme)" =~ theme\:\ x3 ]] && /usr/local/cpanel/bin/uapi --user={} Themes update theme=jupiter' ::: $userlist
	fi

	# convert legacy fantastico installs to softac ones
	ec yellow "Converting Fantastico installations to Softaculous..."
	/usr/local/cpanel/3rdparty/bin/php /usr/local/cpanel/whostmgr/docroot/cgi/softaculous/import.cmd.php 2>&1 | stderrlogit 4

	# change the whm email address back
	restorecontact

	# put some more stuff in the error log
	# shellcheck disable=SC1111
	[ "$(grep 'Mysql::_restore_grants' $dir/log/restorepkg*log)" ] && echo "[ERROR] Some mysql passwords failed to restore (grep \"Mysql::_restore_grants\" $dir/log/restorepkg*log | awk -F'“|”' '{print \$4}'; )" >> $dir/error.log
	[ "$(grep 'Mysql::_restore_db_file' $dir/log/restorepkg*log)" ] && echo "[ERROR] Some mysql databases restored with alternate names (grep \"Mysql::_restore_db_file\" $dir/log/restorepkg*log)" >> $dir/error.log
	# shellcheck disable=SC1111
	[ "$(grep 'Mysql::_restore_dbowner' $dir/log/restorepkg*log)" ] && echo "[ERROR] Some cpanel user mysql passwords failed to restore (grep \"Mysql::_restore_dbowner\" $dir/log/restorepkg*log | awk -F'“|”' '{print \$4}'; )" >> $dir/error.log
	[ "$(grep 'DBD::mysql::db do failed' $dir/log/restorepkg*log)" ] && echo "[ERROR] Some databases failed to restore (grep \"DBD::mysql::db do failed\" $dir/log/restorepkg*log)" >> $dir/error.log
	[ -f $dir/dbmalware.txt ] && echo "[ERROR] Some databases may have malware, which usually indicates that the CMS is hosed. Please check manually! (cat $dir/dbmalware.txt)" >> $dir/error.log
	[ -s $dir/did_not_restore.txt ] && echo "[ERROR] Some $(cat $dir/did_not_restore.txt | wc -w) cPanel users did not restore! (cat $dir/did_not_restore.txt)" >> $dir/error.log
	[ ! "$(awk '$1=="DirectoryIndex" {print $2}' /etc/apache2/conf/httpd.conf)" ] && echo "[ERROR] apache DirectoryIndex priority is not set! Set this up in WHM under 'Apache Configuration' -> 'DirectoryIndex Priority' manually." >> $dir/error.log
	if [ -f /root/dirty_accounts.txt ] && grep -qEx "($(echo $userlist | paste -sd\|))" /root/dirty_accounts.txt; then
		malware_accts=$(grep -Ex "($(echo $userlist | paste -sd\|))" /root/dirty_accounts.txt)
		malware_file_count=$(for i in $malware_accts; do grep 'Flagged as' $dir/log/$i.scan; done | wc -l)
		echo "[ERROR] Malware detected on $(wc -w <<< "$malware_accts") accounts from userlist, totalling $malware_file_count suspicious files (cat /root/dirty_accounts.txt; for i in \$(cat /root/dirty_accounts.txt); do grep -EH '(Flagged as|Cleaning)' $dir/log/\$i.scan; done)" >> $dir/error.log
		cp -a /root/dirty_accounts.txt $dir/
	fi
	[ "$comment_crons" ] && echo "[INFO] Commented crons for users! These will be undone with a resync of crontabs if this script is used for a final sync." >> $dir/error.log

	# find any php module mismatches
	if [[ "$ea" || "$noeaextras" ]]; then
		ec yellow "Comparing PHP module lists..."
		if [ "$remoteea" == "EA3" ]; then
			# collect single php version modules from source, using matching php version from target
			if [ -f /opt/cpanel/ea-php${niceremotephp}/enable ]; then
				phpbin="/opt/cpanel/ea-php${niceremotephp}/root/usr/bin/php"
			else
				phpbin="/opt/cpanel/$defaultea4profile/root/usr/bin/php"
			fi
			# list out modules
			target_modules=$(eval $phpbin -m 2> /dev/null | grep -v -e ^$ -e "\[" -e "(" | paste -sd\| | sed 's/\ /\\\ /g')
			missing_modules=$(sssh "php -m 2> /dev/null" | grep -Ev -e "^($target_modules)$" -e ^$ -e "\[" -e "\(")
			if [ "$missing_modules" ]; then
				# items remain in variable after grep -Ev
				ec red "PHP modules are missing from the target that were installed on source! (cat $dir/missing_php_modules.txt)" | errorlogit 2 root
				echo $missing_modules | tee -a $dir/missing_php_modules.txt
				echo "evaluated using $phpbin" | tee -a $dir/missing_php_modules.txt
				ec red "If you are matching versions, you should address this after the sync!"
			else
				ec green "No modules found on source that were not installed on target already."
			fi
		else
			# remote server using ea4. collect modules for all versions.
			for ver in $(sssh "/usr/local/cpanel/bin/rebuild_phpconf --available" | cut -d: -f1); do
				if [ -f /opt/cpanel/$ver/enable ]; then
					# same version is installed on target
					target_modules=$(/opt/cpanel/$ver/root/usr/bin/php -m 2> /dev/null | grep -v -e ^$ -e "\[" -e "(" | paste -sd\| | sed 's/\ /\\\ /g')
					missing_modules=$(sssh "/opt/cpanel/$ver/root/usr/bin/php -m 2> /dev/null" | grep -Ev -e "^($target_modules)$" -e ^$ -e "\[" -e "\(")
					if [ "$missing_modules" ]; then
						echo $missing_modules >> $dir/missing_php_modules.txt
						echo "evaluated using /opt/cpanel/$ver/root/usr/bin/php" >> $dir/missing_php_modules.txt
					fi
				fi
			done
			if [ -s $dir/missing_php_modules.txt ]; then
				# file has size and therefore missing modules were found
				ec red "PHP modules are missing from the target that were installed on source! (cat $dir/missing_php_modules.txt)" | errorlogit 2 root
				cat $dir/missing_php_modules.txt
				ec red "If you are matching versions, you should address this after the sync!"
			fi
		fi
	fi

	# now that all databases are restored, calculate appropriate mysql variables
	mysqlcalc

	# check for blocklisting of target ip
	blocklist_check

	# print warnings and errors
	if [ -f $dir/error.log ]; then
		ec lightRed "==Errors of note=="
		cat $dir/error.log
		ec lightRed "==Please fix the above issues manually! (see $log for even more details and $dir/error.log for this list again)=="
	fi

	# generate ticket response and perform automatic testing
	hostsfile_gen
	[ $runmarill ] && marill_gen
	[ $initsyncwpt ] && wpt_initcompare
}
