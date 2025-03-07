rd() { #read and log the recorded variable, passed as $1
	# if there is no variable passed, read silently (press enter to continue)
	[ ! "$1" ] && read -rs && return
	# otherwise set the variable passed, and log it
	read -re "$1"
	echo "$(ts) $1 set to $(eval echo "\$$1")" >> "$log"
}
