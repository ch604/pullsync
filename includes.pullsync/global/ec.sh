ec() { #color printing
	# get the color and shift arguments
	local ecolor=${!1}
	shift
	# print remaining args, change back to no color, and log the line
	echo -e ${ecolor}"${*}"${nocolor} | logit
}
