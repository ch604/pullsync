optimizations(){ #server optimizations separated from installs() in case version matching is not needed
	#install ea4-experimental just in case and disable
	yum -y -q install ea4-experimental 2>&1 | stderrlogit 3
	sed -i 's/^enabled=.*$/enabled=0/' /etc/yum.repos.d/EA4-experimental.repo
	#mpm_event
	if [ $mpmevent ]; then
		ec yellow "Ensuring Event MPM..."
		local currentmpm=$(yum -q list installed ea-apache24-mod_mpm_* | awk '!/mpm_itk/ {print $1}' | tail -1)
		if ! echo $currentmpm | grep -q event; then
			ec yellow "Changing $currentmpm to mod_mpm_event..."
			local yumshell=$(mktemp)
			case "$(echo $currentmpm | cut -d_ -f3 | cut -d. -f1)" in
				prefork) echo -e "remove ea-apache24-mod_mpm_prefork\nremove ea-apache24-mod_cgi\ninstall ea-apache24-mod_mpm_worker\ninstall ea-apache24-mod_cgid\nrun" > $yumshell;;
				worker) echo -e "remove ea-apache24-mod_mpm_worker\ninstall ea-apache24-mod_mpm_event\nrun" > $yumshell;;
				*) ec red "I couldn't be sure if this was worker or prefork! Not changing MPM." | errorlogit 3;;
			esac
			[ -s $yumshell ] && yum -y -q shell $yumshell 2>&1 | stderrlogit 4
			rm -f $yumshell
		fi
	fi
	#mod_http2
	if [ $modhttp2 ]; then
		ec yellow "Installing mod_http2..."
		# just in case $mpmevent wasnt selected, make sure we dont have prefork
		if rpm --quiet -q ea-apache24-mod_mpm_prefork; then
			ec yellow "Prefork MPM detected, switching to Event MPM as well..."
			yum -y -q swap -- install ea-apache24-mod_mpm_event -- remove ea-apache24-mod_mpm_prefork 2>&1 | stderrlogit 4
		fi
		yum -y -q install ea-apache24-mod_http2 2>&1 | stderrlogit 4
	fi
	#fpm for all accounts
	if [ $fpmdefault ]; then
		if [ $(/usr/local/cpanel/bin/whmapi1 php_get_default_accounts_to_fpm | awk '/^\s+default_accounts_to_fpm/ {print $2}') -eq 0 ]; then
			ec yellow "Setting default handler for all accounts to FPM..."
			installfpmrpms
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
	if [ $security_tweaks ]; then
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
		[ $(awk -F= '/^minpwstrength=/ {print $2}' $dir/var/cpanel/cpanel.config) -lt 75 ] && /usr/local/cpanel/bin/whmapi1 setminimumpasswordstrengths default=75 2>&1 >/dev/null
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
		if [ "$localea" = "EA4" ]; then
			sed -i '/\"traceenable\"\ \:/ s/[oO]n/Off/' /etc/cpanel/ea4/ea4.conf
			sed -i '/\"serversignature\"\ \:/ s/[oO]n/Off/' /etc/cpanel/ea4/ea4.conf
			sed -i '/\"servertokens\"\ \:/ s/\:\ \"[a-zA-Z]*\"/\:\ \"ProductOnly\"/' /etc/cpanel/ea4/ea4.conf
			sed -i '/\"fileetag\"\ \:/ s/\:\ \"[a-zA-Z]*\"/\:\ \"None\"/' /etc/cpanel/ea4/ea4.conf
		else #local ea3
			if [ -s /var/cpanel/conf/apache/local ]; then
				sed -i '/\"traceenable\"\:/ s/[oO]n/Off/' /var/cpanel/conf/apache/local
				sed -i '/\"serversignature\"\:/ s/[oO]n/Off/' /var/cpanel/conf/apache/local
				sed -i '/\"servertokens\"\:/ s/'\''[a-zA-Z]*'\''/'\''ProductOnly'\''/' /var/cpanel/conf/apache/local
				sed -i '/\"fileetag\"\:/ s/'\''[a-zA-Z]*'\''/'\''None'\''/' /var/cpanel/conf/apache/local
			else
				echo '"traceenable": Off' >> /var/cpanel/conf/apache/local
				echo '"serversignature": Off' >> /var/cpanel/conf/apache/local
				echo "\"servertokens\": 'ProductOnly'" >> /var/cpanel/conf/apache/local
				echo "\"fileetag\": 'None'" >> /var/cpanel/conf/apache/local
			fi
		fi
		/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
	fi
	#memcache
	if [ "$memcache" ]; then
		if ! [ "`which memcached 2> /dev/null`" ]; then
			ec yellow "Installing memcached..."
			yum -q -y install memcached 2>&1 | stderrlogit 4
			if [ "$?" = "0" ]; then
				ec green "Success!"
			fi
		fi
		if [ "`which memcached 2> /dev/null`" ]; then
			if [ "$(rpm --eval %rhel)" -le 6 ]; then #el6
				chkconfig memcached on
				echo "service[memcached]=11211,version,VERSION,/etc/init.d/memcached stop;/etc/init.d/memcached start" > /etc/chkserv.d/memcached
			else #el7+
				systemctl enable memcached.service
				echo "service[memcached]=11211,version,VERSION,systemctl restart memcached.service" > /etc/chkserv.d/memcached
			fi
			service memcached start
			! grep -q memcached /etc/chkserv.d/chkservd.conf && echo "memcached:1" >> /etc/chkserv.d/chkservd.conf
			/scripts/restartsrv_chkservd 2>&1 | stderrlogit 3
			echo "yum -q -y install $(for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do echo -n "$each-php-memcache $each-php-memcached "; done) --enablerepo=EA4-experimental*" | sh 2>&1 | stderrlogit 4
		else
			ec red "Memcache install failed!" | stderrlogit 3
		fi
	fi
	#mod_pagespeed
	if [ $pagespeed ]; then
		ec yellow "Installing mod_pagespeed..."
		yum -q -y install ea-apache24-mod_version ea-apache24-mod_pagespeed --enablerepo=EA4-experimental* 2>&1 | stderrlogit 4
		[ -f /usr/local/apache/conf/pagespeed.conf ] && sed -i '$ i\<Location \/wp-admin\/>\nModPagespeed Off\n<\/Location>' /usr/local/apache/conf/pagespeed.conf
		[ -f /etc/apache2/conf.modules.d/510_pagespeed.conf ] && sed -i '$ i\<Location \/wp-admin\/>\nModPagespeed Off\n<\/Location>' /etc/apache2/conf.modules.d/510_pagespeed.conf
		mkdir -p /var/cache/pagespeed /var/cache/mod_pagespeed
		chown nobody.nobody /var/cache/pagespeed /var/cache/mod_pagespeed
		/scripts/restartsrv_apache 2>&1 | stderrlogit 3
	fi
	#nginx proxy
	if [ $nginxproxy ]; then
		ec yellow "Installing Nginx proxy..."
		yum -q -y install ea-nginx --enablerepo=EA4-experimental* 2>&1 | stderrlogit 4
	fi
}
