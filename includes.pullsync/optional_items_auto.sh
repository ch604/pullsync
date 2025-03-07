optional_items_auto() { #conslidate items used by the optional_items_menu(), but for autopilot
	local source_main_ip source_ip_usage ips_free
	[ "$synctype" = "single" ] && return
	#basically check for dedicated ips free
	source_main_ip=$(awk '/ADDR [0-9]/ {print $2}' "$dir/etc/wwwacct.conf" | tr -d '\n')
	# shellcheck disable=SC2016,SC2086
	source_ip_usage=$(parallel -j 100% -u awk -F= \''/^IP=/ && !/='$source_main_ip'$/ {print $2}'\' $dir/var/cpanel/users/{} ::: $userlist | sort -u | wc -w)
	ips_free=$(whmapi1 listips | grep -c "used: 0")
	[[ $source_ip_usage -le $ips_free ]] && ded_ip_check=1
}
