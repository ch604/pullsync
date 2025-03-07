progressbar() { #takes the current value $1 and total value $2. calculates the size of the current screen and prints a progress bar and %completion based on the input values.
	local width=$(($(tput cols) - 10))
	if [ ${1} -gt ${2} ]; then
		_progress=100
	elif [ ${1} -lt 0 ]; then
		_progress=0
	else
		let _progress=(${1}*100/${2}*100)/100
	fi
	let _done=(${_progress}*${width})/100
	let _left=$width-$_done
	local fill=$(printf "%${_done}s")
	local empty=$(printf "%${_left}s")
	ecnl greyBg "[${fill// /#}${empty// /-}] $_progress%$c"
}
