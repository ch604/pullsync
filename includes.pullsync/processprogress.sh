processprogress() { #shared portion of the final/sync progress functions, depends on $runningprocs being set
	tput cup 0 0
	numprocs=$(echo "$runningprocs" | wc -l)
	[ $numprocs -ne 0 ] && for each in $(seq 1 $numprocs); do
		# collect the line for the process from the runningprocs variable, scrape the username
		local line=$(echo "$runningprocs" | head -n${each} | tail -1)
		local user=$(echo $line | awk '{print $2}')
		# tail the end of the log for that user if it exists
		[ -f $dir/log/looplog.${user}.log ] && local line2=$(tail -1 $dir/log/looplog.${user}.log)
		[ -f $dir/log/dblog.${user}.log ] && local line3=$(tail -1 $dir/log/dblog.${user}.log) || local line3=""
		echo -e "$line2$c"
		echo -e "$line3$c"
		if echo $line2 | grep -q Rsyncing\ homedir ; then
			# if the rsync is in progress, get the open file from lsof and print it
			local openfile=$(lsof -c rsync -F n | grep \/${user}\/ | sed 's/^n//')
			ecnl white "Currently syncing ...$(echo $openfile | rev | cut -d. -f2- | cut -c1-$(($(tput cols) - 24)) | rev)$c" # prevent wrapping
		else
			echo -e "$c"
		fi
		echo -e "$c"
	done
}
