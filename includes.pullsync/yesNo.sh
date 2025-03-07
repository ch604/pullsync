yesNo() { #generic yesNo function, usage: if yesNo "yes?"; then ...
	while true; do
		echo -e "${lightCyan}${*}${white} (Y/N)?${nocolor} " | logit
		read -r yn
		# log the reply with timestamp
		echo "$(ts) $yn" >> "$log"
		case $yn in
			# return true or false
			yes|Yes|YES|y|Y) return 0;;
			no|No|n|N|NO) return 1;;
			*) ec lightRed "Please enter y or n.";;
		esac
	done
}
