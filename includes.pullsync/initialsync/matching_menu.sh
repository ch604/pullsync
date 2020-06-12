matching_menu(){ #this is where a lot of the comparisons between the servers is performed, as part of version matching. builds a menu and does compatibility checks to make partially sane defaults.
	ec yellow "Gathering information..."
	local cmd=(dialog --clear --backtitle "pullsync" --title "Matching Menu" --separate-output --checklist "Select options for version matching. Sane options were selected based on your configuration:\n" 0 0 17)
	local options=( 1 "Match WHM email address" on
			2 "Match Ruby gems" off
			3 "Run UPCP" off
			4 "Copy CL altphp and LVE settings" off
			5 "Copy WHM Tweak Settings (this changes a lot more stuff now!)" on
			6 "Copy CSF rules" off
			7 "Match timezone data" off
			8 "Match sql_mode and innodb_strict_mode" on
			9 "Install PostgreSQL" off
			10 "Open exim on port 26" off
			11 "Turn off LFD alerts" on
			12 "Install loadwatch" off
			13 "Import MySQL access hosts" off
			14 "Upgrade MySQL" off
			15 "Install cPanel's solr for full email text search" off
			16 "Copy mysql settings" off)

	###### turn on things we want to turn on first
	#ruby gems (3 4 5)
	[ `sssh "which gem 2> /dev/null"` ] && [ `which gem 2> /dev/null` ] && options[5]=on && cmd[8]=`echo "${cmd[8]}\n(2) gem executable detected on both servers"`
	#upcp (6 7 8)
	[[ $localcpanel < $remotecpanel ]] && options[8]=on && cmd[8]=`echo "${cmd[8]}\n(3) Local cPanel version lower than remote cPanel version"`
	#CL (9 10 11)
	if echo $local_os | grep -q ^Cloud && echo $remote_os | grep -q ^Cloud; then options[11]=on && cmd[8]=`echo "${cmd[8]}\n(4) CloudLinux detected on both servers"`; fi
	#csf rules (15 16 17)
	[ -e $dir/etc/csf/csf.allow ] && [ -e /etc/csf/csf.allow ] && options[17]=on && cmd[8]=`echo "${cmd[8]}\n(6) CSF detected on both servers"`
	#timezone (18 19 20)
	[ -f $dir/etc/sysconfig/clock ] && remotetimezonefile=`cat $dir/etc/sysconfig/clock | grep ^ZONE | cut -d\" -f2` || remotetimezonefile=`sssh "[ -x /bin/timedatectl ] && timedatectl | grep zone\: | cut -d\: -f2 | awk '{print $1}'"`
	[ -f /etc/sysconfig/clock ] && localtimezonefile=`cat /etc/sysconfig/clock | grep ^ZONE | cut -d\" -f2` || localtimezonefile=`[ -x /bin/timedatectl ] && timedatectl | grep zone\: | cut -d\: -f2 | awk '{print $1}'`
	remotetimezone=`sssh "date +%z"`
	localtimezone=`date +%z`
	if ! [ -z "${remotetimezone}" -o -z "${localtimezone}" -o -z "${remotetimezonefile}" -o -z "${localtimezonefile}" ]; then
		if [ ! "${localtimezone}" = "${remotetimezone}" ] && [ -f "/usr/share/zoneinfo/${remotetimezonefile}" ]; then
			options[20]=on
			cmd[8]=`echo "${cmd[8]}\n(7) Timezones do not match (L=${localtimezone}, R=${remotetimezone}) and can be matched"`
		fi
	fi
	#pgsql (24 25 26)
	if [ "$postgres" ] && [ ! -d /var/lib/pgsql ]; then
		options[26]=on
		cmd[8]=`echo "${cmd[8]}\n(9) Postgres detected on source and not target"`
	fi
	#exim26 (27 28 29)
	remote_exim_ports=`grep ^daemon_smtp_ports $dir/etc/exim.conf | cut -d\= -f2 | tr -d ' ' | tr ':' '\n' | sort`
	local_exim_ports=`grep ^daemon_smtp_ports /etc/exim.conf | cut -d\= -f2 | tr -d ' ' | tr ':' '\n' | sort`
	[ "$remote_exim_ports" != "$local_exim_ports" ] && ! grep -q ^exim-26 /etc/chkserv.d/chkservd.conf && options[29]=on && cmd[8]=`echo "${cmd[8]}\n(10) Exim ports do not match (L=$local_exim_ports, R=$remote_exim_ports)"`
	#mysqlup (39 40 41)
	[ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" = "$remotemysql" ] && [ ! "$remotemysql" = "$localmysql" ] && /usr/local/cpanel/bin/whmapi1 installable_mysql_versions | grep -q \'${remotemysql}\' && options[41]=on && cmd[8]=`echo "${cmd[8]}\n(14) MySQL version is greater on source server (L=${localmysql}, R=${remotemysql}) and can be matched"`
	#cpsolr (42 43 44)
	if [ "$cpanelsolr" ] && [ ! "$(service cpanel-dovecot-solr status 2> /dev/null)" ]; then
		if [ $local_mem -ge 1800 ]; then
			options[44]=on && cmd[8]=`echo "${cmd[8]}\n(15) Remote server has cPanels solr installed, and local server has 2G mem or greater"`
		else
			cmd[8]=`echo "${cmd[8]}\n(15) Remote server has cPanels solr installed, but local server has less than 2G mem; install at your own risk"`
		fi
	fi
	#mysql settings (45 46 47)
	if [ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" = "$localmysql" ] && [ $(( $local_mem + 500 )) -ge $remote_mem ]; then
		remote_sql_ibps=$(sssh "mysql -Nse 'select @@innodb_buffer_pool_size'")
		remote_sql_ibpi=$(sssh "mysql -Nse 'select @@innodb_buffer_pool_instances'")
		remote_sql_toc=$(sssh "mysql -Nse 'select @@table_open_cache'")
		remote_sql_kbs=$(sssh "mysql -Nse 'select @@key_buffer_size'")
		remote_sql_mc=$(sssh "mysql -Nse 'select @@max_connections'")
		local_sql_ibps=$(mysql -Nse 'select @@innodb_buffer_pool_size')
		local_sql_ibpi=$(mysql -Nse 'select @@innodb_buffer_pool_instances')
		local_sql_toc=$(mysql -Nse 'select @@table_open_cache')
		local_sql_kbs=$(mysql -Nse 'select @@key_buffer_size')
		local_sql_mc=$(mysql -Nse 'select @@max_connections')
		if [ ${remote_sql_ibps} -gt ${local_sql_ibps} ] || [ ${remote_sql_ibpi} -gt ${local_sql_ibpi} ] || [ ${remote_sql_toc} -gt ${local_sql_toc} ] || [ ${remote_sql_kbs} -gt ${local_sql_kbs} ] || [ ${remote_sql_mc} -gt ${local_sql_mc} ]; then
			options[47]=on
			cmd[8]=`echo "${cmd[8]}\n(16) One or more critical MySQL variables are higher on source than on target, local MySQL version is greater or equal to source, and local memory is greater or equal to source; critical variables are innodb buffer pool size/instances, table open cache, key buffer size, and max connections."`
		fi
	fi

	###### now that defaults have been set, it is safe to unset needless array elements, starting from the back
	cmd[8]=`echo "${cmd[8]}\n\nThe following options were removed:\n"`
	#mysql settings (45 46 47)
	if [ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" = "$localmysql" ] && [ $(( $local_mem + 500 )) -ge $remote_mem ]; then
		#variables were already created in the same test of the previous stanza
		if [ ${remote_sql_ibps} -le ${local_sql_ibps} ] && [ ${remote_sql_ibpi} -le ${local_sql_ibpi} ] && [ ${remote_sql_toc} -le ${local_sql_toc} ] && [ ${remote_sql_kbs} -le ${local_sql_kbs} ]; then
			unset options[47] options[46] options[45] && cmd[8]=`echo "${cmd[8]}\n(16) Critical MySQL settings already match or are greater on target; critical variables are innodb buffer pool size/instances, table open cache, and key buffer size."`
		fi
	else
		unset options[47] options[46] options[45] && cmd[8]=`echo "${cmd[8]}\n(16) Local server has lower version of MySQL or less ram than source, will not automatically set MySQL variables"`
	fi
	#cpsolr (42 43 44)
	if [ "$cpanelsolr" ]; then
		[ "$(service cpanel-dovecot-solr status 2> /dev/null)" ] && unset options[44] options[43] options[42] && cmd[8]=`echo "${cmd[8]}\n(15) cPanels solr already installed"`
	else
		unset options[44] options[43] options[42] && cmd[8]=`echo "${cmd[8]}\n(15) Remote server does not use cPanels solr"`
	fi
	#mysqlup (39 40 41)
	([ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" = "$localmysql" ] || [ "$remotemysql" = "$localmysql" ] || ! /usr/local/cpanel/bin/whmapi1 installable_mysql_versions | grep -q \'${remotemysql}\') && unset options[41] options[40] options[39] && cmd[8]=`echo "${cmd[8]}\n(14) MySQL versions match, or remote version not installable (L=${localmysql}, R=${remotemysql})"`
	#mysql access hosts (36 37 38)
	[ ! -s ${dir}/var/cpanel/mysqlaccesshosts ] && unset options[38] options[37] options[36] && cmd[8]=`echo "${cmd[8]}\n(13) MySQL access hosts not set on source"`
	#lfd alerts (30 31 32)
	[ ! -e /etc/csf/csf.conf ] && unset options[32] options[31] options[30] && cmd[8]=`echo "${cmd[8]}\n(11) CSF/LFD not detected on target"`
	#pgsql (24 25 26)
	[ "$postgres" ] && [ -d /var/lib/pgsql ] && unset options[26] options[25] options[24] && cmd[8]=`echo "${cmd[8]}\n(9) Postgres already installed on target"`
	[ ! "$postgres" ] && unset options[26] options[25] options[24] && cmd[8]=`echo "${cmd[8]}\n(9) Postgres not detected on source"`
	#timezone (18 19 20)
	[ "${localtimezone}" = "${remotetimezone}" ] || [ -z "${remotetimezone}" -o -z "${localtimezone}" -o -z "${remotetimezonefile}" -o -z "${localtimezonefile}" ] && unset options[20] options[19] options[18] && cmd[8]=`echo "${cmd[8]}\n(7) Some timezone variables could not be set, or timezones already match"`
	#csf allow (15 16 17)
	[ ! -e $dir/etc/csf/csf.allow ] || [ ! -e /etc/csf/csf.allow ] && unset options[17] options[16] options[15] && cmd[8]=`echo "${cmd[8]}\n(6) CSF not detected on one or more servers"`
	#CL (9 10 11)
	! echo $local_os | grep -q ^Cloud || ! echo $remote_os | grep -q ^Cloud && unset options[11] options[10] options[9] && cmd[8]=`echo "${cmd[8]}\n(4) CloudLinux not detected on one or more servers"`
	#ruby gems (3 4 5)
	! [ `sssh "which gem 2> /dev/null"` ] || ! [ `which gem 2> /dev/null` ] && unset options[5] options[4] options[3] && cmd[8]=`echo "${cmd[8]}\n(2) gem executable not detected on one or more servers"`
	cmd[8]=`echo "${cmd[8]}\n\nPlease keep this information in mind when selecting options. Pressing Cancel will be the same as saying 'no' to all options."`

	###### ready to print the menu!
	sleep 1
	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	[ $? != 0 ] && exitcleanup 99
	clear
	echo $choices >> $log
	for choice in $choices; do print_next_element options $choice >> $log; done
	! echo $choices | grep -q -x 9 && unset postgres
	for choice in $choices; do
		case $choice in
			1)	grep ^CONTACTEMAIL\  $dir/etc/wwwacct.conf | awk '{print $2}' > $dir/whmcontact.txt
				setcontact=1;;
			2)	rubymatch=1;;
			3)	upcp=1;;
			4)	cloudlinuxconfig=1;;
			5)	copytweak=1;;
			6)	csfimport=1;;
			7)	matchtimezone=1;;
			8)	match_sqlmode=1;;
			10)	eximon26=1;;
			11)	lfdemailsoff=1;;
			12)	install_loadwatch=1;;
			13)	copyaccesshosts=1;;
			14)	upgrademysql=1;;
			15)	installcpanelsolr=1;;
			16)	matchmysqlvariables=1;;
			*)	:;;
		esac
	done
}
