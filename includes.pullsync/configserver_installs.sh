configserver_installs() { # install configserver items if enabled on source
	mkdir -p /usr/local/src

	for each in cmc cmm cmq cse; do
		if [ "${!each}" ]; then
			ec yellow "$hg Installing $each"
			rm -f /usr/local/src/${each}.tgz
			wget -q -P /usr/local/src http://download.configserver.com/${each}.tgz
			tar -xzf /usr/local/src/${each}.tgz -C /usr/local/src
			(cd /usr/local/src/$each && sh install.sh 2>&1 | stderrlogit 3)
			if [ ! -f /var/cpanel/apps/${each}.conf ]; then
				writexx
				local cspluginfail=1
			else
				writecm
				echo "	$each installed from source" >> /etc/motd
			fi
			rm -f /usr/local/src/${each}.tgz
		fi
	done

	if [ "$mailscanner" ]; then
		ec yellow "Installing ConfigServer Mailscanner..."
		rm -f /usr/local/src/msinstall.tar.gz
		/usr/local/cpanel/scripts/check_cpanel_pkgs --fix --targets=clamav
		wget -q -P /usr/local/src http://download.configserver.com/msinstall.tar.gz
		tar -xzf /usr/local/src/msinstall.tar.gz -C /usr/local/src
		# use expect because the install is interactive
		(cd /usr/local/src/msinstall && expect -c "spawn sh install.sh; expect \"Select an option [1]: \"; send \"\r\"; expect eof" 2>&1 | stderrlogit 3)
		rm -f /usr/local/src/msinstall.tar.gz
		if [ -d /usr/mailscanner ]; then
			writecm
			echo "  MailScanner installed" >> /etc/motd
			[ ! -f /scripts/postupcp ] && echo "#!/bin/sh" >> /scripts/postupcp
			echo "perl /usr/mscpanel/mscheck.pl" >> /scripts/postupcp
			chmod 700 /scripts/postupcp
			/usr/bin/perl /usr/mscpanel/mscpanel.pl -i 2>&1 | stderrlogit 4
			echo "0 0 * * * perl /usr/mscpanel/mscpanel.pl > /dev/null 2>&1" >> /var/spool/cron/root
			echo -e "name=addon_mailscanner\nservice=whostmgr\nurl=/cgi/addon_mailscanner.cgi\nuser=root\nacls=any\ndisplayname=addon_mailscanner" > /var/cpanel/apps/mailscanner.conf
			/usr/local/cpanel/bin/register_appconfig /var/cpanel/apps/mailscanner.conf
			service MailScanner restart 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=skipboxtrapper value=1 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=skipspamassassin value=1 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 configureservice service=spamd enabled=0 monitored=0 2>&1 | stderrlogit 3
		else
			writexx
			local cspluginfail=1
		fi
	fi

	if [ $cspluginfail ]; then
		ec red "Installation of one or more ConfigServer plugins failed!" | errorlogit 3 root
	fi
}
