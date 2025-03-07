ecnl() { #same as ec() but no logging
	# get the color code and shift the arguments down by 1
	local ecolor=${!1}; shift
	# print, changing back to no color after
	echo -e "${ecolor}${*}${nocolor}"
}
