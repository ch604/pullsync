eternallog() { #add a restored/synced user to the eternal log when called. $1 should be user, expects $synctype to be set
	case $synctype in
		single|all|domainlist|list) oper="INITIAL";;
		email|emaillist) oper="EMAIL";;
		*) oper="$(tr '[:lower:]' '[:upper:]' <<< "$synctype")";;
	esac
	echo -en "$(date)==$oper==$dir.$starttime==$1\n" >> /root/migration.log
}
