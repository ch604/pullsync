user_mysql_listgen() { #generate a db list for a single user, requires user be passed as $1, returns stdout
	local user=$1
	# blank string variable to store data
	local list=""
	if [[ -f $dir/var/cpanel/databases/$user.json ]]; then
		# json most accurate, use that first
		list=`cat $dir/var/cpanel/databases/$user.json | python -c 'import sys,json; dbs=json.load(sys.stdin)["MYSQL"]["dbs"].keys() ; print("\n".join(dbs))' | grep -v \* | sed -e 's/\ /\\ /g'`
	elif [[ -f $dir/var/cpanel/databases/$user.yaml ]]; then
		# yaml second most accurate, use that next
		list=`cat $dir/var/cpanel/databases/$user.yaml | python -c 'import sys,yaml; dbs=yaml.load(sys.stdin, Loader=yaml.FullLoader)["MYSQL"]["dbs"].keys() ; print("\n".join(dbs))' | grep -v \* | sed -e 's/\ /\\ /g'`
	else
		# /var/cpanel/databases, may not exist in really old vps, fall back to old unaccurate way
		list=`sssh "mysql -e 'show databases'" | grep ^${user:0:8}\_ | grep -v \* | sed -e 's/\ /\\ /g'`
	fi
	echo "$list"
}
