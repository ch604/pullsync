parallel_unrestored() { #make sure user restored and has all its databases and domains.
	user=$1
	if [ -f "/var/cpanel/users/$user" ]; then
		while read -r domain; do
			if [ "$(/scripts/whoowns "$domain")" == "" ]; then
				ec lightRed "Domain $domain is missing!" | tee -a "$dir/missingthings.txt"
			elif [ "$(/scripts/whoowns "$domain")" != "$user" ]; then
					ec lightRed "Domain $domain exists, but is not owned by $user!" | tee -a "$dir/missingthings.txt"
			fi
		done < <(awk -F= '/^DNS/ {print $2}' "$dir/var/cpanel/users/$user")
		dblist=$(user_mysql_listgen "$user")
		for db in $dblist; do
			if ! sql -Nse 'show databases' | grep -q "^$db$"; then
				ec lightRed "Database $db is missing!" | tee -a "$dir/missingthings.txt"
			elif ! jq -r '.MYSQL.dbs | keys[]' "/var/cpanel/databases/$user.json" | grep -q "^$db$"; then
				ec lightRed "Database $db exists, but is not owned by $user!" | tee -a "$dir/missingthings.txt"
			fi
		done
	else
		ec lightRed "User $user did not restore!" | tee -a "$dir/missingthings.txt"
	fi
}
