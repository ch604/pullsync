getversions() { #this is the other omnibus of pullsync, checks for installed applications and versions on the source server to compare to target.
	ec yellow "Running version detection"

	# store functions to run in both locations
	phpcmd='php -v 2>/dev/null | awk '\''NR==1 {print $2}'\'' '
	mysqlcmd='mysqladmin ver | awk '\''$1=="Server" {print $3}'\'' |cut -d. -f1-2'
	httpcmd='/usr/local/apache/bin/httpd -v | awk '\''$2=="version:" {print $3}'\'' |cut -d/ -f2'
	phphandlercmd='/usr/local/cpanel/bin/rebuild_phpconf --current |grep PHP5 |cut -d" " -f3'
	ea4phphandlercmd="default=\`/usr/local/cpanel/bin/rebuild_phpconf --current | head -1 | awk '{print \$3}'\`; /usr/local/cpanel/bin/rebuild_phpconf --current | grep \$default | tail -1 | awk '{print \$3}'"
	os_cmd='cat /etc/redhat-release'
	mem_cmd='free -m | awk '\''$1=="Mem:" {print $2}'\'''
	proc_type_cmd='cat /proc/cpuinfo | grep ^model\ name | cut -d: -f2 | head -1'
	proc_count_cmd='cat /proc/cpuinfo | grep ^processor | wc -l'

	echo "Versions on local server `hostname`, $cpanel_main_ip:" |tee -a $dir/versionsLocal.txt

	# run the commands, load into variables
	localhttp=`eval $httpcmd`
	localmysql=`eval $mysqlcmd`
	localphp=` eval $phpcmd`
	[ -f /etc/cpanel/ea4/is_ea4 ] && localea=EA4 || localea=EA3
	[ "$localea" = "EA4" ] && localphphandler=`eval $ea4phphandlercmd` || localphphandler=`eval $phphandlercmd`
	localcpanel=`cat /usr/local/cpanel/version`
	local_os=`eval $os_cmd`
	local_mem=`eval $mem_cmd`
	local_proct=`eval $proc_type_cmd`
	local_procc=`eval $proc_count_cmd`
	echo "	Local Http      : $localhttp
	Local Php       : $localphp
	Local Phphandler: $localphphandler
	Local Mysql     : $localmysql
	Local Cpanel    : $localcpanel
	Local EasyApache: $localea
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
	remotephp=`sssh "eval $phpcmd"`
	[ -f $dir/etc/cpanel/ea4/is_ea4 ] && remoteea=EA4 || remoteea=EA3
	[ "$remoteea" = "EA4" ] && remotephphandler=`sssh "eval $ea4phphandlercmd"` || remotephphandler=`sssh "eval $phphandlercmd"`
	remotecpanel=`cat $dir/usr/local/cpanel/version`
	remote_os=`sssh "eval $os_cmd"`
	remote_mem=`sssh "eval $mem_cmd"`
	remote_proct=`sssh "eval $proc_type_cmd"`
	remote_procc=`sssh "eval $proc_count_cmd"`
	echo "	Remote Http      : $remotehttp
	Remote Php       : $remotephp
	Remote Phphandler: $remotephphandler
	Remote Mysql     : $remotemysql
	Remote Cpanel    : $remotecpanel
	Remote EasyApache: $remoteea
	Remote OS        : $remote_os
	Remote Memory    : $remote_mem M
	Remote Processor : $remote_proct
	Remote Core Count: $remote_procc
	" | tee -a $dir/versionsRemote.txt | logit

	# also grab php info from source, for future reference
	sssh "php -m 2>&1; php -i 2>&1" > $dir/remote_php_details.txt

	# extra mysql stuff, look for remote profiles.
	[ ! $localmysql == $remotemysql ] && ec red "Mysql versions do not match."
	say_ok
	mysql_remote_profiles
	mysql_installed_version
	mysql_variables

	# check for disk usage
	space_check
	multihomedir_check

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

	# now that we have a dns file, we can check for modcloudflare install
	if [[ ! "$synctype" = "single" && ! "$synctype" = "skeletons" ]] && [ "$domainlist" ] && [ ! "$localea" = "EA4" ]; then
		[ "$modcloudflarefound" ] || grep -q cloudflare_module $dir/usr/local/apache/conf/includes/pre_main_global.conf 2> /dev/null || grep -q cloudflare.com $dir/source_resolve.txt $dir/not_here_resolve.txt 2> /dev/null && modcloudflare=1
	fi

	# ipv6 checks
	if sssh "cat /etc/sysconfig/network" | grep -qi ^NETWORKING_IPV6=YES; then
		ec red "Source server has IPv6 enabled in /etc/sysconfig/network! See $dir/ipv6_stats.txt for details." | errorlogit 3
		sssh "service cpipv6 status; service cpipv6 list" | tee -a $dir/ipv6_stats.txt
		ec red "This script can't do anything about that yet. Please make sure IPv6 is set up if needed. Not available on Storm!"
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
