matching_menu() { #this is where a lot of the comparisons between the servers is performed, as part of version matching. builds a menu and does compatibility checks to make partially sane defaults.
	local choices
	declare -a cmd options
	ec yellow "Gathering information..."
	cmd=(dialog --clear --backtitle "pullsync" --title "Matching Menu" --separate-output --checklist "Select options for version matching. Sane options were selected based on your configuration:\n" 0 0 17)
	options=( 1 "Match WHM email address" on
		2 "Match Ruby gems" off
		3 "Run UPCP" off
		4 "Copy CL altphp and LVE settings" off
		5 "Copy WHM Tweak Settings" on
		6 "Copy CSF rules" off
		7 "Match timezone data" off
		8 "Match sql_mode and innodb_strict_mode" on
		9 "Import ModSec rules" off
		10 "Open exim on port 26" off
		11 "Turn off LFD alerts" on
		12 "Install loadwatch" off
		13 "Import MySQL access hosts" off
		14 "Upgrade MySQL" off
		15 "Install cPanel's solr for full email text search" off
		16 "Copy mysql settings" off)

	###### turn on things we want to turn on first
	#ruby gems (3 4 5)
	if sssh "which gem &> /dev/null" && which gem &> /dev/null; then
		options[5]=on
		cmd[8]="${cmd[8]}\n(2) gem executable detected on both servers"
	fi
	#upcp (6 7 8)
	#TODO adjust this check since the cpanel version has a xx.xx.x.xx format
	if [ "$localcpanel" -lt "$remotecpanel" ]; then
		options[8]=on
		cmd[8]="${cmd[8]}\n(3) Local cPanel version lower than remote cPanel version"
	fi
	#CL (9 10 11)
	if grep -qi ^cloud <<< "$local_os" && grep -qi ^cloud <<< "$remote_os"; then
		options[11]=on
		cmd[8]="${cmd[8]}\n(4) CloudLinux detected on both servers"
	fi
	#csf rules (15 16 17)
	if [ -e "$dir/etc/csf/csf.allow" ] && [ -e /etc/csf/csf.allow ]; then
		options[17]=on
		cmd[8]="${cmd[8]}\n(6) CSF detected on both servers"
	fi
	#timezone (18 19 20)
	timezone_check
	if [[ "${remotetimezone}" && "${localtimezone}" && "${remotetimezonefile}" && "${localtimezonefile}" ]] && [ ! "${localtimezone}" == "${remotetimezone}" ] && [ -f "/usr/share/zoneinfo/${remotetimezonefile}" ]; then
		options[20]=on
		cmd[8]="${cmd[8]}\n(7) Timezones do not match (L=${localtimezone}, R=${remotetimezone}) and can be matched"
	fi
	#sql_mode (21 22 23)
	if grep -qi almalinux <<< "$local_os"; then
		options[23]=off
		cmd[8]="${cmd[8]}\n(8) Target server is AlmaLinux, not matching sql_mode"
	fi
	#modsec (24 25 26)
	if [ ! -s /etc/apache2/conf.d/modsec2/whitelist.conf ] && [[ -s "$dir/usr/local/apache/conf/modsec2/whitelist.conf" || -s $dir/etc/apache2/conf.d/modsec2/whitelist.conf ]]; then
		options[26]=on
		cmd[8]="${cmd[8]}\n(9) Local modsec whitelist.conf empty"
	fi
	#exim26 (27 28 29)
	remote_exim_ports=$(awk -F= '/^daemon_smtp_ports/ {print $2}' "$dir/etc/exim.conf" | tr -d ' ' | tr ':' '\n' | sort)
	local_exim_ports=$(awk -F= '/^daemon_smtp_ports/ {print $2}' /etc/exim.conf | tr -d ' ' | tr ':' '\n' | sort)
	if [ "$remote_exim_ports" != "$local_exim_ports" ] && ! grep -q ^exim-26 /etc/chkserv.d/chkservd.conf; then
		options[29]=on
		cmd[8]="${cmd[8]}\n(10) Exim ports do not match (L=$local_exim_ports, R=$remote_exim_ports)"
	fi
	#mysqlup (39 40 41)
	if [ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" == "$remotemysql" ] && [ "$remotemysql" != "$localmysql" ] && /usr/local/cpanel/bin/whmapi1 installable_mysql_versions | grep -q "'$remotemysql'"; then
		options[41]=on
		cmd[8]="${cmd[8]}\n(14) MySQL version is greater on source server (L=$localmysql, R=$remotemysql) and can be matched"
	fi
	#cpsolr (42 43 44)
	if [ "$cpanelsolr" ] && [ ! "$(service cpanel-dovecot-solr status 2> /dev/null)" ]; then
		if [ "$local_mem" -ge 1800 ]; then
			options[44]=on
			cmd[8]="${cmd[8]}\n(15) Remote server has cPanels solr installed, and local server has 2G mem or greater"
		else
			cmd[8]="${cmd[8]}\n(15) Remote server has cPanels solr installed, but local server has less than 2G mem; install at your own risk"
		fi
	fi
	#mysql settings (45 46 47)
	if [ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" = "$localmysql" ] && [ "$((local_mem + 500))" -ge "$remote_mem" ]; then
		for _v in $sql_variables; do
			eval "remote_sql_$_v"="$(sssh_sql -Nse "select @@$_v" 2> /dev/null)"
			eval "local_sql_$_v"="$(sql -Nse "select @@$_v" 2> /dev/null)"
			if [ "$(eval echo "\${remote_sql_$_v:-1}")" -gt "$(eval echo "\${local_sql_$_v:-1}")" ]; then
				_sql_settings_up=1
			fi
		done
		if [ "$_sql_settings_up" ]; then
			options[47]=on
			cmd[8]="${cmd[8]}\n(16) One or more critical MySQL variables are higher on source than on target, local MySQL version is greater or equal to source, and local memory is greater or equal to source; critical variables are innodb buffer pool size/instances, table open cache, key buffer size, and max connections."
		fi
	fi

	###### now that defaults have been set, it is safe to unset needless array elements, starting from the back
	cmd[8]="${cmd[8]}\n\nThe following options were removed:\n"
	#mysql settings (45 46 47)
	if [ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" = "$localmysql" ] && [ "$((local_mem + 500))" -ge "$remote_mem" ]; then
		#variables were already created in the same test of the previous stanza
		if [ ! "$_sql_settings_up" ]; then
			unset "options[47]" "options[46]" "options[45]"
			cmd[8]="${cmd[8]}\n(16) Critical MySQL settings already match or are greater on target; critical variables are innodb buffer pool size/instances, table open cache, and key buffer size."
		fi
	else
		unset "options[47]" "options[46]" "options[45]"
		cmd[8]="${cmd[8]}\n(16) Local server has lower version of MySQL or less ram than source, will not automatically set MySQL variables"
	fi
	#cpsolr (42 43 44)
	if [ "$cpanelsolr" ]; then
		service cpanel-dovecot-solr status &> /dev/null && unset "options[44]" "options[43]" "options[42]" && cmd[8]="${cmd[8]}\n(15) cPanels solr already installed"
	else
		unset "options[44]" "options[43]" "options[42]" && cmd[8]="${cmd[8]}\n(15) Remote server does not use cPanels solr"
	fi
	#mysqlup (39 40 41)
	if [ "$(echo -e "$remotemysql\n$localmysql" | sort -rV | head -1)" == "$localmysql" ] || [ "$remotemysql" == "$localmysql" ] || ! whmapi1 installable_mysql_versions | grep -q "'$remotemysql'"; then
		unset "options[41]" "options[40]" "options[39]"
		cmd[8]="${cmd[8]}\n(14) MySQL versions match, or remote version not installable (L=$localmysql, R=$remotemysql)"
	fi
	#mysql access hosts (36 37 38)
	if [ ! -s "$dir/var/cpanel/mysqlaccesshosts" ]; then
		unset "options[38]" "options[37]" "options[36]"
		cmd[8]="${cmd[8]}\n(13) MySQL access hosts not set on source"
	fi
	#lfd alerts (30 31 32)
	if [ ! -e /etc/csf/csf.conf ]; then
		unset "options[32]" "options[31]" "options[30]"
		cmd[8]="${cmd[8]}\n(11) CSF/LFD not detected on target"
	fi
	#modsec (24 25 26)
	if [[ -s /etc/apache2/conf.d/modsec2/whitelist.conf || -s /usr/local/apache/conf/modsec2/whitelist.conf ]]; then
		unset "options[26]" "options[25]" "options[24]"
		cmd[8]="${cmd[8]}\n(9) Local modsec whitelist.conf contains data already"
	fi
	#timezone (18 19 20)
	if [[ "${localtimezone}" == "${remotetimezone}" || ! "${remotetimezone}" || ! "${localtimezone}" || ! "${remotetimezonefile}" || ! "${localtimezonefile}" ]]; then
		unset "options[20]" "options[19]" "options[18]"
		cmd[8]="${cmd[8]}\n(7) Some timezone variables could not be set, or timezones already match"
	fi
	#csf allow (15 16 17)
	if [[ ! -e $dir/etc/csf/csf.allow || ! -e /etc/csf/csf.allow ]]; then
		unset "options[17]" "options[16]" "options[15]"
		cmd[8]="${cmd[8]}\n(6) CSF not detected on one or more servers"
	fi
	#CL (9 10 11)
	if ! grep -qi ^cloud <<< "$local_os" || ! grep -qi ^cloud <<< "$remote_os"; then
		unset "options[11]" "options[10]" "options[9]"
		cmd[8]="${cmd[8]}\n(4) CloudLinux not detected on one or more servers"
	fi
	#ruby gems (3 4 5)
	if ! sssh "which gem &> /dev/null" || ! which gem &> /dev/null; then
		unset "options[5]" "options[4]" "options[3]"
		cmd[8]="${cmd[8]}\n(2) gem executable not detected on one or more servers"
	fi

	cmd[8]="${cmd[8]}\n\nPlease keep this information in mind when selecting options. Pressing Cancel will be the same as saying 'no' to all options."

	###### ready to print the menu!
	sleep 1
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty) || exitcleanup 99
	clear
	for choice in $choices; do
		echo "$choice" >> "$log"
		print_next_element options "$choice" >> "$log"
		case $choice in
			1)	awk '/^CONTACTEMAIL / {print $2}' "$dir/etc/wwwacct.conf" > "$dir/whmcontact.txt"
				setcontact=1;;
			2)	rubymatch=1;;
			3)	upcp=1;;
			4)	cloudlinuxconfig=1;;
			5)	copytweak=1;;
			6)	csfimport=1;;
			7)	matchtimezone=1;;
			8)	match_sqlmode=1;;
			9)	modsecimport=1;;
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
