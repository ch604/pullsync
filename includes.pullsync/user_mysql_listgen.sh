user_mysql_listgen() { #generate a list of dbs owned on source server for a single user, requires user be passed as $1, returns stdout
	local user=$1
	[ -n "$user" ] || return 1
	if [ -f "$dir/var/cpanel/databases/$user.json" ]; then
		# json most accurate, use that first
		jq -r '.MYSQL.dbs | keys[]' "$dir/var/cpanel/databases/$user.json" 2> /dev/null | grep -v "\*" | sed -e 's/\ /\\ /g' -e '/^$/d'
	elif [ -f "$dir/var/cpanel/databases/$user.yaml" ]; then
		# yaml second most accurate, use that next
		python -c 'import sys,yaml; dbs=yaml.load(sys.stdin, Loader=yaml.FullLoader)["MYSQL"]["dbs"].keys() ; print("\n".join(dbs))' < "$dir/var/cpanel/databases/$user.yaml" 2> /dev/null | grep -v "\*" | sed -e 's/\ /\\ /g' -e '/^$/d'
	else
		# /var/cpanel/databases, may not exist in really old vps, fall back to old unaccurate way
		sssh_sql -e 'show databases' | grep "^${user:0:8}_" | grep -v "\*" | sed -e 's/\ /\\ /g' -e '/^$/d'
	fi
}
