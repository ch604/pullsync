mysqlprogress() { #displays the running tables for a db passed as $1 with no newline
	# shellcheck disable=SC2009
	echo -ne "${white}Syncing table(s): $(ps ax | grep "parallel_mysql_dbsync $1" | grep -vE '(grep|parallel\ )' | awk '{print $NF}' | sort -u | paste -sd' ' | cut -c1-$(($(tput cols) - 21)))...$c\r${nocolor}"
}