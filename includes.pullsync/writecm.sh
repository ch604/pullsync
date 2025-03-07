writecm() {
	echo -e "$cm Success!" >> "$log"
	echo -e "\r\e[1A$cm"
}