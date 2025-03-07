writewn() {
	echo -e "$wn Warning!" >> "$log"
	echo -e "\r\e[1A$wn"
}