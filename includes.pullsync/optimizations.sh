optimizations(){ #server optimizations separated from installs() in case version matching is not needed
	local currentmpm tmpfile yumshell
	#install ea4-experimental just in case and disable
	yum -yq install ea4-experimental 2>&1 | stderrlogit 3
	if [ -f /etc/yum.repos.d/EA4-experimental.repo ]; then
		sed -i 's/^enabled=.*$/enabled=0/' /etc/yum.repos.d/EA4-experimental.repo
	else
		ec yellow "ea4-experimental repo did not install, possibly on EL9. This is fine." | errorlogit 4 root
	fi

	#mpm_event
	if [ "$mpmevent" ]; then
		currentmpm=$(yum -q list installed ea-apache24-mod_mpm_* | awk '!/mpm_itk/ {print $1}' | tail -1)
		if ! echo "$currentmpm" | grep -q event; then
			ec yellow "$hg Changing $currentmpm to mod_mpm_event"
			yumshell=$(mktemp)
			case "$(echo "$currentmpm" | cut -d_ -f3 | cut -d. -f1)" in
				prefork) echo -e "remove ea-apache24-mod_mpm_prefork\nremove ea-apache24-mod_cgi\ninstall ea-apache24-mod_mpm_worker\ninstall ea-apache24-mod_cgid\nrun" > "$yumshell";;
				worker) echo -e "remove ea-apache24-mod_mpm_worker\ninstall ea-apache24-mod_mpm_event\nrun" > "$yumshell";;
				*) writexx; ec red "I couldn't be sure if this was worker or prefork! Not changing MPM." | errorlogit_ 3 root;;
			esac
			[ -s "$yumshell" ] && yum -yq shell "$yumshell" 2>&1 | stderrlogit 4 && writecm
			rm -f "$yumshell"
		fi
	fi

	#mod_http2
	if [ "$modhttp2" ]; then
		ec yellow "$hg Installing mod_http2 and ensuring no prefork"
		# just in case $mpmevent wasnt selected, make sure we dont have prefork
		if rpm --quiet -q ea-apache24-mod_mpm_prefork; then
			ec yellow "Prefork MPM detected, switching to Event MPM as well..."
			yum -y -q swap -- install ea-apache24-mod_mpm_event -- remove ea-apache24-mod_mpm_prefork 2>&1 | stderrlogit 4
		fi
		yum -y -q install ea-apache24-mod_http2 2>&1 | stderrlogit 4
		writecm
	fi

	#fpm for all accounts
	if [ "$fpmdefault" ]; then
		if [ "$(whmapi1 php_get_default_accounts_to_fpm | awk '/^\s+default_accounts_to_fpm/ {print $2}')" -eq 0 ]; then
			ec yellow "$hg Setting default handler for all accounts to FPM"
			installfpmrpms
			whmapi1 php_set_default_accounts_to_fpm default_accounts_to_fpm=1 2>&1 | stderrlogit 3
			writecm
		else
			ec yellow "Default handler for all accounts already set to FPM. Skipping..."
		fi
	fi

	#keepalive, mod_expires, mod_deflate
	if [ "$basicoptimize" ]; then
		ec yellow "$hg Enabling basic apache optimizations"
		basic_optimize_deflate
		basic_optimize_expires
		basic_optimize_keepalive
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		writecm
	fi

	#security tweaks
	if [ "$security_tweaks" ]; then
		ec yellow "$hg Enabling security settings"
		#csf
		sed -i -e 's/\(SMTP_BLOCK = \)"0"/\1"1"/' -e 's/\(SYSLOG_CHECK = \)"0"/\1"1"' -e 's/\(LF_SCRIPT_ALERT = \)"0"/\1"1"' -e 's/\(SAFECHAINUPDATE = \)"0"/\1"1"/' -e 's/\(PT_ALL_USERS = \)"0"/\1"1"/' -e 's/\(RESTRICT_SYSLOG = \)"0"/\1"2"/' /etc/csf/csf.conf
		sed -i -e 's/#\(DSHIELD\)/\1/' -e 's/#\(SPAMDROP\)/\1/' -e 's/#\(SPAMEDROP\)/\1/' /etc/csf/csf.blocklists
		whmapi1 set_tweaksetting key=smtpmailgidonly value=0 &> /dev/null
		/scripts/smtpmailgidonly off &> /dev/null
		csf -ra &> /dev/null
		#whm tweaks
		for each in cgihidepass referrerblanksafety referrersafety skipboxtrapper userdirprotect nobodyspam alwaysredirecttossl; do
			whmapi1 set_tweaksetting key=$each value=1 &> /dev/null
		done
		## turn things off
		for each in resetpass resetpass_sub proxysubdomains; do
			whmapi1 set_tweaksetting key=$each value=0 &> /dev/null
		done
		[ "$(awk -F= '/^minpwstrength=/ {print $2}' "$dir"/var/cpanel/cpanel.config)" -lt 80 ] && whmapi1 setminimumpasswordstrengths default=80 &> /dev/null
		#php tweaks
		for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
			[ -s "/opt/cpanel/$each/root/etc/php.d/local.ini" ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
			sed -ri 's/^(display_errors\ =\ )(1|[Oo]n)/\1Off/' "$file"
			! grep -q "^display_errors " "$file" && echo "display_errors = Off" >> "$file"
			sed -ri 's/^(expose_php\ =\ )(1|[Oo]n)/\1Off/' "$file"
			! grep -q "^expose_php " "$file" && echo "expose_php = Off" >> "$file"
			sed -ri 's/^(enable_dl\ =\ )(1|[Oo]n)/\1Off/' "$file"
			! grep -q "^enable_dl " "$file" && echo "enable_dl = Off" >> "$file"
			if grep -q "^disable_functions " "$file"; then
				# only populate if disable_functions is blank ("")
				sed -ri 's/^(disable_functions\ =\ )""/\1"show_source,system,shell_exec,passthru,exec,phpinfo,proc_open,allow_url_fopen,ini_set"/' "$file"
			else
				echo "disable_functions = \"show_source,system,shell_exec,passthru,exec,phpinfo,proc_open,allow_url_fopen,ini_set\"" >> "$file"
			fi
		done
		#httpd tweaks
		sed -i -e '/\"traceenable\"\ \:/ s/[oO]n/Off/' -e '/\"serversignature\"\ \:/ s/[oO]n/Off/' -e '/\"servertokens\"\ \:/ s/\:\ \"[a-zA-Z]*\"/\:\ \"ProductOnly\"/' -e '/\"fileetag\"\ \:/ s/\:\ \"[a-zA-Z]*\"/\:\ \"None\"/' /etc/cpanel/ea4/ea4.conf
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		#ftp tweaks
		/scripts/setupftpserver disabled 2>&1 | stderrlogit 3
		/scripts/setupftpserver pure-ftpd 2>&1 | stderrlogit 3
		touch /var/cpanel/conf/pureftpd/root_password_disabled
		sed -i -e 's/^TLS: .*/TLS: 2/' -e 's/^TLSCipherSuite: .*/TLSCipherSuite: \x27HIGH\x27/' -e 's/^AnonymousCantUpload: .*/AnonymousCantUpload: \x27yes\x27/' /var/cpanel/conf/pureftpd/main
		systemctl restart pure-ftpd 2>&1 | stderrlogit 3
		#mail tweaks
		/scripts/dovecot_set_defaults.pl 2>&1 | stderrlogit 3
		sed -i -e 's/^disable_plaintext_auth: .*/disable_plaintext_auth: \x27yes\x27/' -e 's/^login_process_per_connection: .*/login_process_per_connection: \x27yes\x27/' -e 's/^ssl_cipher_list: .*/ssl_cipher_list: ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256/' -e 's/^ssl_min_protocol: .*/ssl_min_protocol: TLSv1.2/' -e 's/^ssl_protocols: .*/ssl_protocols: TLSv1.2/' /var/cpanel/conf/dovecot/main
		sed -i 's/^tls_require_ciphers=.*/tls_require_ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256/' /etc/exim.conf.localopts
		/scripts/builddovecotconf 2>&1 | stderrlogit 3
		/scripts/buildeximconf 2>&1 | stderrlogit 3
		systemctl restart dovecot 2>&1 | stderrlogit 3
		systemctl restart exim 2>&1 | stderrlogit 3
		#ensure users cannot access modsec settings
		if ! grep -q "modsecurity=0" /var/cpanel/features/default; then
			tmpfile=$(mktemp)
			echo "modsecurity=0" >> /var/cpanel/features/default
			sort /var/cpanel/features/default > "$tmpfile"
			cat "$tmpfile" > /var/cpanel/features/default
			rm -f "$tmpfile"
		fi
		#misc
		if ! mount | grep /dev/shm | grep -q noexec; then
			sed -i '/\/dev\/shm/ s/^/#/' /etc/fstab
			echo "tmpfs  /dev/shm  auto  defaults,nosuid,noexec  0 0" >> /etc/fstab
			systemctl daemon-reload &> /dev/null
			mount -o remount /dev/shm &> /dev/null
		fi
		/scripts/compilers off &> /dev/null
		/scripts/userdirctl on &> /dev/null
		writecm
	fi

	#memcache
	if [ "$memcache" ]; then
		if ! which memcached &> /dev/null; then
			ec yellow "$hg Installing memcached"
			yum -yq install memcached 2>&1 | stderrlogit 4
			writecm
		fi
		if which memcached &> /dev/null; then
			ec yellow "$hg Enabling memcached"
			if [ "$(rpm --eval %rhel)" -le 6 ]; then #el6
				chkconfig memcached on 2>&1 | stderrlogit 4
				echo "service[memcached]=11211,version,VERSION,/etc/init.d/memcached stop;/etc/init.d/memcached start" > /etc/chkserv.d/memcached
				/etc/init.d/memcached start 2>&1 | stderrlogit 4
			else #el7+
				systemctl enable memcached.service 2>&1 | stderrlogit 4
				echo "service[memcached]=11211,version,VERSION,systemctl restart memcached.service" > /etc/chkserv.d/memcached
				systemctl start memcached.service 2>&1 | stderrlogit 4
			fi
			! grep -q memcached /etc/chkserv.d/chkservd.conf && echo "memcached:1" >> /etc/chkserv.d/chkservd.conf
			/scripts/restartsrv_chkservd 2>&1 | stderrlogit 3
			if [ -f /etc/yum.repos.d/EA4-experimental.repo ]; then
				echo "yum -yq install $(for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do echo -n "$each-php-memcache $each-php-memcached "; done) --enablerepo=EA4-experimental* --skip-broken" | sh 2>&1 | stderrlogit 4
			else
				echo "yum -yq install $(for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do echo -n "$each-php-memcache $each-php-memcached "; done) --skip-broken" | sh 2>&1 | stderrlogit 4
			fi
			writecm
		fi
	fi

	#mod_pagespeed
	if [ "$pagespeed" ]; then
		ec yellow "$hg Installing mod_pagespeed"
		if [ -f /etc/yum.repos.d/EA4-experimental.repo ]; then
			yum -yq install ea-apache24-mod_version ea-apache24-mod_pagespeed --enablerepo=EA4-experimental* 2>&1 | stderrlogit 4
		else
			yum -yq install ea-apache24-mod_version ea-apache24-mod_pagespeed 2>&1 | stderrlogit 4
		fi
		[ -f /usr/local/apache/conf/pagespeed.conf ] && sed -i '$ i\<Location \/wp-admin\/>\nModPagespeed Off\n<\/Location>' /usr/local/apache/conf/pagespeed.conf
		[ -f /etc/apache2/conf.modules.d/510_pagespeed.conf ] && sed -i '$ i\<Location \/wp-admin\/>\nModPagespeed Off\n<\/Location>' /etc/apache2/conf.modules.d/510_pagespeed.conf
		mkdir -p /var/cache/pagespeed /var/cache/mod_pagespeed
		chown nobody.nobody /var/cache/pagespeed /var/cache/mod_pagespeed
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		writecm
	fi
	#nginx proxy
	if [ "$nginxproxy" ]; then
		ec yellow "$hg Installing Nginx proxy"
		if [ -f /etc/yum.repos.d/EA4-experimental.repo ]; then
			yum -yq install ea-nginx ea-nginx-http2 ea-nginx-gzip --enablerepo=EA4-experimental* 2>&1 | stderrlogit 4
		else
			yum -yq install ea-nginx ea-nginx-http2 ea-nginx-gzip 2>&1 | stderrlogit 4
		fi
		writecm
	fi
}
