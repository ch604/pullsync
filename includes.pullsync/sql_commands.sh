# solve mariadb vs mysql binary fork. sql() for local commands, sssh_sql for remote ones.
sql() {
	local _cmdtype EXITCODE
	case $1 in
		dump|admin|upgrade) _cmdtype=$1; shift;;
		*)	:;;
	esac
	if which mariadb &> /dev/null; then
		case $_cmdtype in
			dump)	mariadb-dump "$@";;
			admin)	mariadb-admin "$@";;
			upgrade) mariadb-upgrade "$@";;
			*)	mariadb "$@";;
		esac
		EXITCODE=$?
	else
		case $_cmdtype in
			dump)	mysqldump "$@";;
			admin)	mysqladmin "$@";;
			upgrade) mysql_upgrade "$@";;
			*)	mysql "$@";;
		esac
		EXITCODE=$?
	fi
	return "$EXITCODE"
}

sssh_sql() {
	local _cmdtype EXITCODE
	case $1 in
		dump|admin)	_cmdtype=$1; shift;;
		upgrade)	return 1;;
		*)	:;;
	esac
	if sssh "which mariadb" &> /dev/null; then
		case $_cmdtype in
			dump)	sssh -nC "mariadb-dump $(printf "%q " "$@")";;
			admin)	sssh -n "mariadb-admin $(printf "%q " "$@")";;
			*)	sssh "mariadb $(printf "%q " "$@")";;
		esac
		EXITCODE=$?
	else
		case $_cmdtype in
			dump)	sssh -nC "mysqldump $(printf "%q " "$@")";;
			admin)	sssh -n "mysqladmin $(printf "%q " "$@")";;
			*)	sssh "mysql $(printf "%q " "$@")";;
		esac
		EXITCODE=$?
	fi
	return "$EXITCODE"
}