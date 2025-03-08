user_pgsql_listgen() { #generate a list of dbs owned on source server for a single user, requires user be passed as $1, returns stdout
	local user=$1
	[ -n "$user" ] || return 1
	if [ -f "$dir/var/cpanel/databases/$user.json" ]; then
		# json most accurate, use that first
		jq -r '.PGSQL.dbs | keys[]' "$dir/var/cpanel/databases/$user.json" 2> /dev/null
	elif [[ -f $dir/var/cpanel/databases/$user.yaml ]]; then
		# yaml second most accurate, use that next
		python -c 'import sys,yaml; dbs=yaml.load(sys.stdin, Loader=yaml.FullLoader)["PGSQL"]["dbs"].keys() ; print("\n".join(dbs))' < "$dir/var/cpanel/databases/$user.yaml" 2> /dev/null
	fi
}
