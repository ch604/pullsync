progressbar() { #takes the current value $1 and total value $2. calculates the size of the current screen and prints a progress bar and %completion based on the input values.
	local width progress finished left fill empty
	width=$(($(tput cols) - 10))
	if [ "$1" -gt "$2" ]; then
		progress=100
	elif [ "$1" -lt 0 ]; then
		progress=0
	else
		# shellcheck disable=SC2017
		(( progress=(${1}*100/${2}*100)/100 ))
	fi
	(( finished=(progress*width)/100 ))
	(( left=width-finished ))
	fill=$(printf "%${finished}s")
	empty=$(printf "%${left}s")
	ecnl greyBg "[${fill// /#}${empty// /-}] $_progress%$c"
}
