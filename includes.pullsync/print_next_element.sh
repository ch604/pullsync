print_next_element(){ #prints the next element in an array. used to save the description of options passed from dialog. usage: $(print_next_element arrayname valuetocheckfor)
	# import the array by name
	eval haystack=\( \"\$\{"$1"[@]\}\" \)
	local needle=$2
	for i in $( seq 0 $((${#haystack[@]} - 1))); do
		# run through the array one by one to check for the value we are checking for
		if [[ ${haystack[i]} == "$needle" ]]; then
			# if there is a match, print the next element and quit the function
			echo "$needle -> ${haystack[$((i+1))]}"
			return 0
		fi
	done
	# we should only be here if the needle wasnt found in the haystack
	echo "$needle not found"
	return 1
}
