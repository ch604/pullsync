writexx() {
	echo -e "$xx Failure!" >> "$log"
	echo -e "\r\e[1A$xx"
}