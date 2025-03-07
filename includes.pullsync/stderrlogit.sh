stderrlogit() { #silently log to stderr log. level (1-4) should be passed as $1
	# same as errlogit, but pass the output to the stderr log
	case $1 in
		1) local level=FATAL; shift;;
		2) local level=ERROR; shift;;
		3) local level=WARN; shift;;
		4) local level=INFO; shift;;
		*) local level=NONE;;
	esac
	while read -r line; do
		# prepend the timestamp and level prefix, and append the line to the stderr log without printing to console
		echo "$(ts) [$level] $line" >> "$stderrlog"
	done
}
