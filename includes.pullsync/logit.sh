logit() { #print passed stdin, add a timestamp and also echo to the logfile
	while read line; do
		# print the line, and the add the line with a timestamp to the logfile
		echo "$line"
		echo "$(ts) $line" >> $log
	done
}
