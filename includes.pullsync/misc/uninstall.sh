uninstall() { #cleanup all data from pullsync
	if yesNo "Delete transient backup files, extra downloaded files, everything from all /home/temp/pullsync* folders, and then delete this script? This does not clean up any data on any other machine."; then
		ec yellow "In addition to various backup files, the following folders would be REMOVED RECURSIVELY if executed:"
		find /home/temp/ -maxdepth 1 -name "pullsync*" -o -name "noop-pullsync*" | logit
		ec red "ARE YOU REALLY REALLY SURE?!?!? This thing will use RM RF, yo."
		if yesNo "For real?"; then
			ec yellow "Locating files and folders to delete (you have 5 seconds to override)..."
			sleep 5
			#pointless to keep logging at this point...
			unset log
			unset dir
			grep -q pullsync /etc/motd && sed -i '/pullsync/d' /etc/motd
			[ -f /root/.ssh/config ] && grep -q pullsync /root/.ssh/config && sed -i '/\#added\ by\ pullsync/,+4d' /root/.ssh/config
			\rm -f /root/.ssh/pullsync* 2>&1
			for file in userlist.txt dns.txt domainlist.txt; do \rm -f /root/$file 2>&1; done
			for file in hosts.txt hostsfile.txt moxxi.sh; do \rm -f /usr/local/apache/htdocs/$file 2>&1; done
			\rm -f /etc/chkserv.d/chkservd.conf.pullsync.bak 2>&1
			\rm -f /etc/exim.conf.pullsync.bak 2>&1
			\rm -f /usr/my.cnf.syncbak /etc/my.cnf.syncbak 2>&1
			\rm -f /etc/cpbackup.conf.syncbak 2>&1
			\rm -f /etc/apf/allow_hosts.rules.pullsyncbak 2>&1
			\rm -f /scripts/db{yaml,json}.pl 2>&1
			\rm -f /root/get-pip.py 2>&1
			\rm -f /etc/localtime.pullsync.bak /etc/sysconfig/clock.pullsync.bak 2>&1
			\rm -f /etc/wwwacct.conf.pullsync.bak 2>&1
			\rm -f /root/migration_scan /root/dirty_accounts.txt 2>&1
			\rm -f /root/marill 2>&1
			\rm -f /etc/mailhelo.ipswap /etc/mailips.ipswap 2>&1
			\rm -f /etc/mail/spamassassin/local.cf.pullsync.bak 2>&1
			\rm -f /var/cpanel/backups/config.pullsync 2>&1
			\rm -f /var/cpanel/conf/apache/local.pullsync.bak /var/cpanel/conf/apache/main.pullsync.bak 2>&1
			\rm -f /root/dontaddzonefiles
			find /home/temp/ -maxdepth 1 \( -name "pullsync*" -o -name "noop-pullsync*" \) -exec \rm -rf '{}' \; &> /dev/null
			ecnl white "Daisy, Daisy..."
			\rm -rf /root/includes.pullsync/ &> /dev/null
			\rm -rf /root/pullsync/ &> /dev/null
			\rm -f /root/pullsync.sh &> /dev/null
			exit 404
		fi
	fi
}
