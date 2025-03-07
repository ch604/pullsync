logit() { #print passed stdin, add a timestamp and also echo to the logfile
	while read -r line; do
		echo "$line"
		echo "$(ts) $line" >> "$log"
	done
}
