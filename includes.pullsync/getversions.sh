getversions() { #this is the other omnibus of pullsync, checks for installed applications and versions on the source server to compare to target.
	local local_http remote_http local_procc remote_procc localmysqlrelease remotemysqlrelease
	ec yellow "Running version detection"

	# run the commands, load into variables
	local_http=$(httpd -v | awk -F"[ /.]" '$2=="version:" {print $4"."$5}')
	localmysql=$(whmapi1 -o json current_mysql_version | jq -r '.data.version')
	localmysqlrelease=$(whmapi1 -o json current_mysql_version | jq -r '.data.server')
	grep -qi -e mariadb -e percona <<< "$localmysqlrelease" || localmysqlrelease="mysql"
	localphp=$(whmapi1 -o json php_get_system_default_version | jq -r ".data.version")
	localphphandler=$(whmapi1 -o json php_get_handlers | jq -r '.data.version_handlers[] | select(.version=="'"$localphp"'") | .current_handler')
	localcpanel=$(cat /usr/local/cpanel/version)
	local_os=$(awk -F= '$1=="ID" {print $2}; $1=="VERSION_ID" {print $2}' /etc/os-release | paste -sd_ | tr -d '"')
	local_mem=$(($(awk '$1=="MemTotal:" {print $2}' /proc/meminfo) / 1024))
	local_procc=$(grep -c ^processor /proc/cpuinfo)

	# run them for a remote server
	remote_http=$(sssh "httpd -v" | awk -F"[ /.]" '$2=="version:" {print $4"."$5}')
	remotemysql=$(sssh "whmapi1 -o json current_mysql_version" | jq -r '.data.version')
	remotemysqlrelease=$(sssh "whmapi1 -o json current_mysql_version" | jq -r '.data.server')
	grep -qi -e mariadb -e percona <<< "$remotemysqlrelease" || remotemysqlrelease="mysql"
	remotephp=$(sssh "whmapi1 -o json php_get_system_default_version" | jq -r ".data.version")
	[ -f "$dir/etc/cpanel/ea4/is_ea4" ] && remoteea=EA4 || remoteea=EA3
	if [ "$remoteea" == "EA4" ]; then
		remotephphandler=$(sssh "whmapi1 -o json php_get_handlers" | jq -r '.data.version_handlers[] | select(.version=="'"$localphp"'") | .current_handler')
	else
		remotephphandler=$(sssh "/usr/local/cpanel/bin/rebuild_phpconf --current" | grep PHP5 | awk '{print $NF}')
	fi
	remotecpanel=$(cat "$dir/usr/local/cpanel/version")
	remote_os=$(sssh "cat /etc/os-release" | awk -F= '$1=="ID" {print $2}; $1=="VERSION_ID" {print $2}' | paste -sd_ | tr -d '"')
	remote_mem=$(sssh "cat /proc/meminfo" | awk '$1=="MemTotal:" {print $2}')
	remote_procc=$(sssh "grep -c ^processor /proc/cpuinfo")

	ec white "==Versions=="
	echo "_ Source Target
	Hostname $(sssh "hostname") $(hostname)
	MainIP ${ip:-x} ${cpanel_main_ip:-0}
	HTTP ${remote_http:-0} ${local_http:-0}
	PHPVer ${remotephp:-0} ${localphp:-0}
	Handler ${remotephphandler:-0} ${localphphandler:-0}
	SQLFork ${remotemysqlrelease:-0} ${localmysqlrelease:-0}
	SQLVer ${remotemysql:-0} ${localmysql:-0}
	cPanel ${remotecpanel:-0} ${localcpanel:-0}
	OS ${remote_os:-0} ${local_os:-0}
	Mem ${remote_mem:-0}M ${local_mem:-0}M
	ProcNum ${remote_procc:-0} ${local_procc:-0}
	" | column -t | tee -a "$dir/versions.txt" | logit
	echo "" | logit

	# also grab php info from source, for future reference
	sssh "php -m 2>&1; php -i 2>&1" > "$dir/remote_php_details.txt"

	# extra mysql stuff, look for remote profiles.
#	[ ! $localmysql == $remotemysql ] && ec red "Mysql versions do not match."
#	[ ! "$localmysqlrelease" = "$remotemysqlrelease" ] && ec lightRed "Mysql releases do not match! Fix this before continuing if the customer cares about their mysql fork!"
	if [ "$remotemysqlrelease" = "MySQL" ] && [[ $remotemysql =~ ^8\. ]]; then
		if [ ! "$localmysqlrelease" = "MySQL" ] || [[ ! $localmysql =~ ^8\. ]]; then
			ec lightRed "Source is using MySQL 8 and target isnt! ($localmysqlrelease $localmysql). Please change the target to MySQL 8 before continuing." | errorlogit 2 root
		fi
	fi
	say_ok
	mysql_remote_profiles
	mysql_installed_version
	mysql_variables

	# check for disk usage
	multihomedir_check
	space_check

	# check for stuff we can install
	if [[ ! "$synctype" = "single" && ! "$synctype" = "skeletons" ]]; then #dont need to check on single
		detect_apps
	fi

	# cpnat check
	cpnat_check

	# dns checks
	dnscheck
	printrdns
	dnsclustering

	# ipv6 checks
	if sssh "/usr/local/cpanel/bin/whmapi1 ipv6_range_list" | grep -q CIDR; then
		ec red "Source server has IPv6 enabled in /etc/sysconfig/network! See $dir/ipv6_stats.txt for details." | errorlogit 3 root
		sssh "service cpipv6 status 2> /dev/null; /usr/local/cpanel/bin/whmapi1 listipv6s; /usr/local/cpanel/bin/whmapi1 ipv6_range_list" | tee -a "$dir/ipv6_stats.txt"
		if /usr/local/cpanel/bin/whmapi1 ipv6_range_list | grep -q CIDR; then
			ec green "Target server also has IPv6 set up in WHM. Sites using IPv6 will get one assigned automatically when restored."
			ipv6=1
		else
			ec red "Target server does not have IPv6 ranges set up. Please make sure IPv6 is configured if needed before proceeding." | errorlogit 3 root
		fi
		say_ok
	fi

	# enabled nameserver binary check
	nsprog_check

	# SSL cert check, just make sure that autossl is on/off
	if [ "$(sssh "/usr/local/cpanel/bin/whmapi1 get_autossl_providers" | awk '/enabled/ {print $2}' | sort | tail -1)" -eq 1 ]; then
		ec yellow "Source server is using AutoSSL. We will turn on LE AutoSSL by default at the successful conclusion of this script."
	else
		ec red "Source server is NOT using AutoSSL. We will turn on LE AutoSSL by default at the successful conclusion of this script."
	fi

	# ruby check
	ruby_check

	# cpbackup check
	! echo -e "single\nskeletons" | grep -qx "$synctype" && backup_check

	# cloudlinux
	cloudlinux_check

	# detect security features
	securityfeatures

	# check for resource limit hits in the past
	resource_limit_check
}
