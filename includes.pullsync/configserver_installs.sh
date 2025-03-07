configserver_installs() { # install configserver items if enabled on source
	mkdir -p /usr/local/src

	if [ "$cmc" ]; then
		ec yellow "Installing ConfigServer ModSecurity Control (cmc)..."
		wget -q -P /usr/local/src http://download.configserver.com/cmc.tgz
		tar -xzf /usr/local/src/cmc.tgz -C /usr/local/src
		pushd /usr/local/src/cmc 2>&1 | stderrlogit 4
		sh install.sh 2>&1 | stderrlogit 3
		[ ! ${PIPESTATUS[0]} -eq 0 ] && local cspluginfail=1
		popd 2>&1 | stderrlogit 4
	fi

	if [ "$cmm" ]; then
		ec yellow "Installing ConfigServer Mail Manage (cmm)..."
		wget -q -P /usr/local/src http://download.configserver.com/cmm.tgz
		tar -xzf /usr/local/src/cmm.tgz -C /usr/local/src
		pushd /usr/local/src/cmm 2>&1 | stderrlogit 4
		sh install.sh 2>&1 | stderrlogit 3
		[ ! ${PIPESTATUS[0]} -eq 0 ] && local cspluginfail=1
		popd 2>&1 | stderrlogit 4
	fi

	if [ "$cmq" ]; then
		ec yellow "Installing ConfigServer Mail Queues (cmq)..."
		wget -q -P /usr/local/src http://download.configserver.com/cmq.tgz
		tar -xzf /usr/local/src/cmq.tgz -C /usr/local/src
		pushd /usr/local/src/cmq 2>&1 | stderrlogit 4
		sh install.sh 2>&1 | stderrlogit 3
		[ ! ${PIPESTATUS[0]} -eq 0 ] && local cspluginfail=1
		popd 2>&1 | stderrlogit 4
	fi

	if [ "$cse" ]; then
		ec yellow "Installing ConfigServer Exlporer (cse)..."
		wget -q -P /usr/local/src http://download.configserver.com/cse.tgz
		tar -xzf /usr/local/src/cse.tgz -C /usr/local/src
		pushd /usr/local/src/cse 2>&1 | stderrlogit 4
		sh install.sh 2>&1 | stderrlogit 3
		[ ! ${PIPESTATUS[0]} -eq 0 ] && local cspluginfail=1
		popd 2>&1 | stderrlogit 4
	fi

	if [ "$mailscanner" ]; then
		ec yellow "Installing ConfigServer Mailscanner..."
		/usr/local/cpanel/scripts/check_cpanel_rpms --fix --targets=clamav
		wget -q -P /usr/local/src http://download.configserver.com/msinstall.tar.gz
		tar -xzf /usr/local/src/msinstall.tar.gz -C /usr/local/src
		pushd /usr/local/src/msinstall 2>&1 | stderrlogit 4
		# use expect because the install is interactive
		expect -c "spawn sh install.sh; expect \"Select an option [1]: \"; send \"\r\"; expect eof" 2>&1 | stderrlogit 3
		[ ! ${PIPESTATUS[0]} -eq 0 ] && local cspluginfail=1
		popd 2>&1 | stderrlogit 4
		if [ -d /usr/mailscanner ]; then
			# install was successful, finidh up with crons and settings
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

		fi
	fi

	if [ $cspluginfail ]; then
		ec red "Installation of one or more ConfigServer plugins failed!" | errorlogit 3
	fi
}
