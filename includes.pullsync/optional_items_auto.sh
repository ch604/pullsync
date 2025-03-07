optional_items_auto(){ #conslidate items used by the optional_items_menu(), but for autopilot
	[ "$synctype" = "single" ] && return
	#basically check for dedicated ips free
	local source_main_ip=$(awk '/ADDR [0-9]/ {print $2}' $dir/etc/wwwacct.conf | tr -d '\n')
	local dedicated_ips=""
	for user in $userlist; do dedicated_ips="$dedicated_ips $(awk -F= '/^IP=/ && !/='$source_main_ip'$/ {print $2}' $dir/var/cpanel/users/$user)"; done
	local source_ip_usage=$(echo $dedicated_ips | tr ' ' '\n' | sort -u | wc -w)
	local ips_free=$(/usr/local/cpanel/bin/whmapi1 listips | grep used\:\ 0 | wc -l)
	[[ $source_ip_usage -le $ips_free ]] && ded_ip_check=1 || ded_ip_check=0
}
