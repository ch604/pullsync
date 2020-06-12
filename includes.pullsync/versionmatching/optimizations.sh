optimizations(){ #server optimizations separated from installs() in case version matching is not needed
	#mod_http2
	if [ $modhttp2 ]; then
		ec yellow "Installing mod_http2..."
		if rpm --quiet -q ea-apache24-mod_mpm_prefork; then
			ec yellow "Prefork MPM detected, switching to Event MPM as well..."
			yum -y -q swap -- install ea-apache24-mod_mpm_event -- remove ea-apache24-mod_mpm_prefork 2>&1 | stderrlogit 4
		fi
		yum -y -q install ea-apache24-mod_http2 2>&1 | stderrlogit 4
	fi
	#fpm for all accounts
	if [ $fpmdefault ]; then
		installfpmrpms
		if [ $(/usr/local/cpanel/bin/whmapi1 php_get_default_accounts_to_fpm | egrep "^\s+default_accounts_to_fpm" | awk '{print $2}') -eq 0 ]; then
			ec yellow "Setting default handler for all accounts to FPM..."
			/usr/local/cpanel/bin/whmapi1 php_set_default_accounts_to_fpm default_accounts_to_fpm=1 2>&1 | stderrlogit 3
		else
			ec yellow "Default handler for all accounts already set to FPM. Skipping..."
		fi
	fi
	#keepalive, mod_expires, mod_deflate
	if [ $basicoptimize ]; then
		basic_optimize_deflate
		basic_optimize_expires
		basic_optimize_keepalive
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
	fi
	#serversecure plus tweaks
	if [ $ssp_tweaks ]; then
		ec yellow "Enabling security settings..."
		#csf
		perl -i -p -e 's/SMTP_BLOCK = "0"/SMTP_BLOCK = "1"/g' /etc/csf/csf.conf
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=smtpmailgidonly value=0 &> /dev/null
		perl -i -p -e 's/SYSLOG_CHECK = "0"/SYSLOG_CHECK = "3600"/g' /etc/csf/csf.conf
		perl -i -p -e 's/#DSHIELD/DSHIELD/g' /etc/csf/csf.blocklists
		perl -i -p -e 's/#SPAMDROP/SPAMDROP/g' /etc/csf/csf.blocklists
		perl -i -p -e 's/#SPAMEDROP/SPAMEDROP/g' /etc/csf/csf.blocklists
		perl -i -p -e 's/LF_SCRIPT_ALERT = "0"/LF_SCRIPT_ALERT = "1"/g' /etc/csf/csf.conf
		perl -i -p -e 's/SAFECHAINUPDATE = "0"/SAFECHAINUPDATE = "1"/g' /etc/csf/csf.conf
		perl -i -p -e 's/PT_ALL_USERS = "0"/PT_ALL_USERS = "1"/g' /etc/csf/csf.conf
		perl -i -p -e 's/RESTRICT_SYSLOG = "0"/RESTRICT_SYSLOG = "2"/g' /etc/csf/csf.conf
		/scripts/smtpmailgidonly off
		csf -ra 2>&1 >/dev/null
		#whm tweaks
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=cgihidepass value=1 2>&1 >/dev/null
		[ $(grep ^minpwstrength= $dir/var/cpanel/cpanel.config | cut -d= -f2) -lt 75 ] && /usr/local/cpanel/bin/whmapi1 setminimumpasswordstrengths default=75 2>&1 >/dev/null
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=referrerblanksafety value=1 2>&1 >/dev/null
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=referrersafety value=1 2>&1 >/dev/null
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=resetpass value=0 2>&1 >/dev/null
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=resetpass_sub value=0 2>&1 >/dev/null
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=proxysubdomains value=0 2>&1 >/dev/null
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=skipboxtrapper value=1 2>&1 >/dev/null
		/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=userdirprotect value=1 2>&1 >/dev/null
		ec green "Done!"
		#php tweaks
		for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
			[ -s /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
			sed -ri 's/^(display_errors\ =\ )(1|[Oo]n)/\1Off/' $file
			! grep -q ^display_errors\  $file && echo "display_errors = Off" >> $file
			sed -ri 's/^(expose_php\ =\ )(1|[Oo]n)/\1Off/' $file
			! grep -q ^expose_php\  $file && echo "expose_php = Off" >> $file
			sed -ri 's/^(enable_dl\ =\ )(1|[Oo]n)/\1Off/' $file
			! grep -q ^enable_dl\  $file && echo "enable_dl = Off" >> $file
			grep -q ^disable_functions\  $file && sed -ri 's/^(disable_functions\ =\ )""/\1"show_source,system,shell_exec,passthru,exec,phpinfo,proc_open,allow_url_fopen,ini_set"/' $file || echo "disable_functions = \"show_source,system,shell_exec,passthru,exec,phpinfo,proc_open,allow_url_fopen,ini_set\"" >> $file
		done
		#httpd tweaks
		sed -i '/\"traceenable\"\:/ s/[oO]n/Off/' /var/cpanel/conf/apache/local
		sed -i '/\"serversignature\"\:/ s/[oO]n/Off/' /var/cpanel/conf/apache/local
		sed -i '/\"servertokens\"\:/ s/'\''[a-zA-Z]*'\''/'\''ProductOnly'\''/' /var/cpanel/conf/apache/local
		sed -i '/\"fileetag\"\:/ s/'\''[a-zA-Z]*'\''/'\''None'\''/' /var/cpanel/conf/apache/local
		/scripts/rebuildhttpdconf
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
	fi
	#memcache
	if [ "$memcache" ]; then
		if [ "`which memcached 2> /dev/null`" ]; then
			ec yellow "memcached already installed, making sure its running and php modules are installed..."
			service memcached start
			if [ "$(echo $local_os | grep -o '[0-9]\+' | head -n1)" -ne 7 ]; then #cent6
				chkconfig memcached on
			else
				systemctl enable memcached.service
			fi
			yum -q -y install ea4-experimental 2>&1 | stderrlogit 4
			sed -i 's/^enabled=.*$/enabled=0/' /etc/yum.repos.d/EA4-experimental.repo
			echo "yum -q -y install $(for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do echo -n "$each-php-memcache $each-php-memcached "; done) --enablerepo=EA4-experimental" | sh 2>&1 | stderrlogit 4
		else
			ec yellow "Installing memcached..."
			yum -q -y install memcached 2>&1 | stderrlogit 4
			if [ "$?" = "0" ]; then
				ec green "Success!"
				ec yellow "Installing php modules..."
				if [ "$(echo $local_os | grep -o '[0-9]\+' | head -n1)" -ne 7 ]; then #cent6
					chkconfig memcached on
					echo "service[memcached]=11211,version,VERSION,/etc/init.d/memcached stop;/etc/init.d/memcached start" > /etc/chkserv.d/memcached
				else #cent7
					systemctl enable memcached.service
					echo "service[memcached]=11211,version,VERSION,systemctl restart memcached.service" > /etc/chkserv.d/memcached
				fi
				service memcached start
				echo "memcached:1" >> /etc/chkserv.d/chkservd.conf
				/scripts/restartsrv_chkservd 2>&1 | stderrlogit 3
				yum -q -y install ea4-experimental 2>&1 | stderrlogit 4
				sed -i 's/^enabled=.*$/enabled=0/' /etc/yum.repos.d/EA4-experimental.repo
				for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
					yum -q -y install $each-php-memcache $each-php-memcached --enablerepo=EA4-experimental 2>&1 | stderrlogit 4
				done
			else
				ec red "Install of memcache failed!" | errorlogit 3
			fi
		fi
	fi
	#mod_pagespeed
	if [ $pagespeed ]; then
		yum install -y -q ea-apache24-mod_version 2>&1 | stderrlogit 4
		/scripts/plbake mod_pagespeed
		sed -i '$ i\<Location \/wp-admin\/>\nModPagespeed Off\n<\/Location>' /usr/local/apache/conf/pagespeed.conf
		mkdir -p /var/cache/pagespeed /var/cache/mod_pagespeed
		chown nobody.nobody /var/cache/pagespeed /var/cache/mod_pagespeed
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
	fi
}
