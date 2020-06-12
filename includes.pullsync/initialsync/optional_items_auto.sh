optional_items_auto(){ #conslidate items used by the optional_items_menu(), but for autopilot
	[ "$synctype" = "single" ] && return
	#basically check for dedicated ips free
	local source_main_ip=`cat $dir/etc/wwwacct.conf|grep "ADDR\ [0-9]" | awk '{print $2}' | tr -d '\n'`
	local dedicated_ips=""
	for user in $userlist; do dedicated_ips="$dedicated_ips `grep ^IP\= $dir/var/cpanel/users/$user |grep -v $source_main_ip | cut -d= -f2`"; done
	local source_ip_usage=`echo $dedicated_ips |tr ' ' '\n' |sort |uniq |wc -w`
	local ips_free=`/usr/local/cpanel/bin/whmapi1 listips | grep used\:\ 0 | wc -l`
	[[ $source_ip_usage -le $ips_free ]] && ded_ip_check=1 || ded_ip_check=0
}
