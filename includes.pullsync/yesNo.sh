yesNo() { #generic yesNo function, usage: if yesNo "yes?"; then ...
	while true; do
		# read every parameter given to the yesNo function, like ec()
		echo -e "${lightCyan}${*}${white} (Y/N)?${nocolor} " | logit
		#junk holds any extra parameters, yn holds the first parameter
		read yn junk
		# log the reply with timestamp
		echo "$(ts) $yn" >> $log
		case $yn in
			# return true or false
			yes|Yes|YES|y|Y) return 0;;
			no|No|n|N|NO) return 1;;
			*) ec lightRed "Please enter y or n.";;
		esac
	done
}
