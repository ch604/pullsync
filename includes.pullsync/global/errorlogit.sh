errorlogit() { #log to normal error log, stripping color codes. level (1-4) should be passed as $1
	case $1 in
		1) local level=FATAL; shift;;
		2) local level=ERROR; shift;;
		3) local level=WARN; shift;;
		4) local level=INFO; shift;;
		*) local level=NONE;;
	esac
	while read line; do
		# print the line to stdout, and then log the line with the level prefix and without color codes to error.log
		echo $line
		echo "[$level] $line" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" >> $dir/error.log
	done
}
