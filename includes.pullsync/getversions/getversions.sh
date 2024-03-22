getversions() { #this is the other omnibus of pullsync, checks for installed applications and versions on the source server to compare to target.
	ec yellow "Running version detection"

	# store functions to run in both locations
	phpcmd='php -v 2>/dev/null | awk '\''NR==1 {print $2}'\'' '
	mysqlcmd='mysqladmin ver | awk '\''$1=="Server" {print $3}'\'' |cut -d. -f1-2'
	mysqlreleasecmd='mysql -Nse "select @@version_comment" | awk '\''{print $1}'\'' '
	httpcmd='/usr/local/apache/bin/httpd -v | awk '\''$2=="version:" {print $3}'\'' |cut -d/ -f2'
	phphandlercmd='/usr/local/cpanel/bin/rebuild_phpconf --current |grep PHP5 |cut -d" " -f3'
	ea4phphandlercmd="default=\`/usr/local/cpanel/bin/rebuild_phpconf --current | head -1 | awk '{print \$3}'\`; /usr/local/cpanel/bin/rebuild_phpconf --current | grep \$default | tail -1 | awk '{print \$3}'"
	modsec_cmd='rpm -q lp-modsec2-rules lp-modsec2-rules-ea4 serversecureplus-modsec2-rules serversecureplus-modsec2-rules-ea4 | grep -v "not installed"' #only check for lp rules, as that is all that is attempted for matching
	os_cmd='cat /etc/redhat-release'
	mem_cmd='free -m | awk '\''$1=="Mem:" {print $2}'\'''
	proc_type_cmd="grep ^model\ name /proc/cpuinfo | head -1 | cut -d: -f2"
	proc_count_cmd='grep ^processor /proc/cpuinfo | wc -l'

	echo "Versions on local server `hostname`, $cpanel_main_ip:" |tee -a $dir/versionsLocal.txt

	# run the commands, load into variables
	localhttp=`eval $httpcmd`
	localmysql=`eval $mysqlcmd`
	localmysqlrelease=`eval $mysqlreleasecmd`
	echo $localmysqlrelease | grep -qi -e MariaDB -e Percona || localmysqlrelease="MySQL"
	localphp=` eval $phpcmd`
	localphphandler=`eval $ea4phphandlercmd`
	localcpanel=`cat /usr/local/cpanel/version`
	localmodsec=`eval $modsec_cmd`
	local_os=`eval $os_cmd`
	local_mem=`eval $mem_cmd`
	local_proct=`eval $proc_type_cmd`
	local_procc=`eval $proc_count_cmd`
	echo "	Local Http      : $localhttp
	Local Php       : $localphp
	Local Phphandler: $localphphandler
	Local Mysql     : $localmysqlrelease $localmysql
	Local Cpanel    : $localcpanel
	Local Modsec    : $localmodsec
	Local OS        : $local_os
	Local Memory	: $local_mem M
	Local Processor : $local_proct
	Local Core Count: $local_procc
	" | tee -a $dir/versionsLocal.txt | logit

	# run them for a remote server
	remotehostname=`sssh "hostname"`
	echo "Versions on $remotehostname $ip:" |tee -a $dir/versionsRemote.txt
	remotehttp=`sssh "eval $httpcmd"`
	remotemysql=`sssh "eval $mysqlcmd"`
	remotemysqlrelease=`sssh "eval $mysqlreleasecmd"`
	echo $remotemysqlrelease | grep -qi -e MariaDB -e Percona || remotemysqlrelease="MySQL"
	remotephp=`sssh "eval $phpcmd"`
	[ -f $dir/etc/cpanel/ea4/is_ea4 ] && remoteea=EA4 || remoteea=EA3
	[ "$remoteea" = "EA4" ] && remotephphandler=`sssh "eval $ea4phphandlercmd"` || remotephphandler=`sssh "eval $phphandlercmd"`
	remotecpanel=`cat $dir/usr/local/cpanel/version`
	remotemodsec=`sssh "eval $modsec_cmd"`
	remote_os=`sssh "eval $os_cmd"`
	remote_mem=`sssh "eval $mem_cmd"`
	remote_proct=`sssh "eval $proc_type_cmd"`
	remote_procc=`sssh "eval $proc_count_cmd"`
	echo "	Remote Http      : $remotehttp
	Remote Php       : $remotephp
	Remote Phphandler: $remotephphandler
	Remote Mysql     : $remotemysqlrelease $remotemysql
	Remote Cpanel    : $remotecpanel
	Remote EasyApache: $remoteea
	Remote Modsec    : $remotemodsec
	Remote OS        : $remote_os
	Remote Memory    : $remote_mem M
	Remote Processor : $remote_proct
	Remote Core Count: $remote_procc
	" | tee -a $dir/versionsRemote.txt | logit

	# also grab php info from source, for future reference
	sssh "php -m 2>&1; php -i 2>&1" > $dir/remote_php_details.txt

	# extra mysql stuff, look for remote profiles.
	[ ! $localmysql == $remotemysql ] && ec red "Mysql versions do not match."
	[ ! "$localmysqlrelease" = "$remotemysqlrelease" ] && ec lightRed "Mysql releases do not match! Fix this before continuing if the customer cares about their mysql fork!"
	if [ "$remotemysqlrelease" = "MySQL" ] && [[ $remotemysql =~ ^8\. ]]; then
		if [ ! "$localmysqlrelease" = "MySQL" ] || [[ ! $localmysql =~ ^8\. ]]; then
			ec lightRed "Source is using MySQL 8 and target isnt! ($localmysqlrelease $localmysql). Please change the target to MySQL 8 before continuing."
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
	if sssh "cat /etc/sysconfig/network" | grep -qi ^NETWORKING_IPV6=YES; then
		ec red "Source server has IPv6 enabled in /etc/sysconfig/network! See $dir/ipv6_stats.txt for details." | errorlogit 3
		sssh "service cpipv6 status; service cpipv6 list" | tee -a $dir/ipv6_stats.txt
		ec red "This script can't do anything about that yet. Please make sure IPv6 is set up if needed. Good luck."
		say_ok
	fi

	# enabled nameserver binary check
	nsprog_check

	# SSL cert check
	sslcert_check

	# ruby check
	ruby_check

	# cpbackup check
	[[ ! "$synctype" = "single" && ! "$synctype" = "skeletons" ]] && backup_check

	# cloudlinux
	cloudlinux_check

	# detect security features
	securityfeatures

	# check for resource limit hits in the past
	resource_limit_check
}
