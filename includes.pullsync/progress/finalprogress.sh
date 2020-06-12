finalprogress() { #same as syncprogress(), but for final syncs.
	# embrace nothingness
	clear
	local c=$(tput el) #variable to clear to end of line
	while kill -0 $1 2> /dev/null; do
		#read refresh delay file every loop, ensure sanity
		refreshdelay=$(cat $dir/refreshdelay); [[ ! $refreshdelay =~ ^[0-9]+$ || $refreshdelay -gt 60 ]] && refreshdelay=3
		# get a list of running parallel processes (finalfunction), printing only the unique command numbers and usernames
		local runningprocs=`ps faux | grep finalfunction | egrep -v '(parallel|grep)' | awk '{print $(NF-2), $(NF-1)}' | sort -u`
		# put that list into processprogress()
		processprogress
		#tell tech which accounts are done
		ecnl green "Completed users:$c"
		echo -e "$(cat $dir/final_complete_users.txt | tr '\n' ' ')$c"
		#invert count to clear off extra data when you go from 3 to 2 restores, for instance
		for each in `seq $numprocs 2`; do
			echo -e "$c\n$c\n$c"
		done
		#clear to the bottom
		for each in `seq 30 $(tput lines)`; do
			echo -e "$c"
		done
		# wait for more stuff to happen
		sleep $refreshdelay
	done
	clear
}
