uninstall() { #cleanup all data from pullsync
	if yesNo "Delete transient backup files, extra downloaded files, everything from all /home/temp/pullsync* folders, and then delete this script? This does not clean up any data on any other machine."; then
		ec yellow "In addition to various backup files, the following folders would be REMOVED RECURSIVELY if executed:"
		find /home/temp/ -maxdepth 1 -name "pullsync*" -o -name "noop-pullsync*" | logit
		find /var/lib/ -maxdepth 1 -name "pgsql.bak.*" | logit
		ec red "ARE YOU REALLY REALLY SURE?!?!? This thing will use RM RF, yo."
		if yesNo "For real?"; then
			ec yellow "Locating files and folders to delete (you have 5 seconds to override)..."
			sleep 5
			# pointless to keep logging at this point...
			unset log
			unset dir

			# motd
			grep -q pullsync /etc/motd && sed -i '/pullsync/d' /etc/motd

			# ssh key
			[ -f /root/.ssh/config ] && grep -q pullsync /root/.ssh/config && sed -i '/\#added\ by\ pullsync/,+4d' /root/.ssh/config
			rm -f /root/.ssh/pullsync*

			# root folder
			for file in /root/marill /root/bin/marill /root/db_exclude.txt /root/db_include.txt /root/userlist.txt /root/dns.txt /root/domainlist.txt /root/dirty_accounts.txt /root/dontaddzonefiles /root/.forward.syncbak /root/migration_scan /root/get-pip.py /root/maintenance /root/rsync_exclude.txt /root/bin/versionfinder; do
				rm -f $file
			done
			rm -rf /root/ipswap-ethconfigs/
			rm -rf /root/pullsync/

			# etc
			for file in /etc/chkserv.d/chkservd.conf.pullsync.bak /etc/cpanel/ea4/ea4.conf.pullsync.bak /etc/apache2/conf.d/deflate.conf.pullsync.bak /etc/apache2/conf.d/expires.conf.pullsync.bak /etc/exim.conf.pullsync.bak /etc/cpbackup.conf.syncbak /etc/apf/allow_hosts.rules.pullsyncbak /etc/localtime.pullsync.bak /etc/sysconfig/clock.pullsync.bak /etc/wwwacct.conf.pullsync.bak /etc/mailhelo.ipswap /etc/mailips.ipswap /etc/mail/spamassassin/local.cf.pullsync.bak /etc/my.cnf.syncbak /etc/cron.d/pullsync-cleanup; do
				rm -f $file
			done

			# opt
			find /opt/cpanel/ \( -name "php.ini.pullsyncbak" -o -name "local.ini.pullsyncbak" \) -exec rm -f '{}' \;

			# scripts
			rm -f /scripts/dbjson.pl
			rm -f /scripts/dbyaml.pl

			# usr
			rm -f /usr/my.cnf.syncbak
			for file in hosts.txt hostsfile.txt moxxi.sh; do rm -f /usr/local/apache/htdocs/$file; done
			find /usr/local/apache/conf/includes/ -maxdepth 1 -name "*.pullsync" -exec rm -f '{}' \;

			# var
			for file in /var/cpanel/conf/apache/main.pullsync.bak /var/cpanel/backups/config.pullsync /var/cpanel/conf/apache/local.pullsync.bak /var/cpanel/cpanel.config.mysqlverbak /var/cpanel/users.cache.ipswap /var/cpanel/conf/apache/primary_virtual_hosts.conf.ipswap; do
				rm -f $file
			done
			rm -rf /var/named.ipswap/
			rm -rf /var/cpanel/globalcache/cpanel.cache.ipswap/
			find /var/lib/ -maxdepth 1 -name "pgsql.bak.*" -exec rm -rf '{}' \;

			# pullsync temp dirs
			find /home/temp/ -maxdepth 1 \( -name "pullsync*" -o -name "noop-pullsync*" \) -exec rm -rf '{}' \;

			ecnl white "Daisy, Daisy..."
			rm -rf /root/includes.pullsync/
			rm -f /root/pullsync.sh
			exit 1
		fi
	fi
}
