nonhuman() { #remove human readable suffixes from variables like 64M -> 67108864
	[ "$1" ] || return 1
	local out suffix
	out=$(tr -d 'a-zA-Z' <<< "$1")
	suffix=$(tr -d '0-9B' <<< "$1")
	case $suffix in
		k|K) out=$((out*1024 ));;
		m|M) out=$((out*1048576 ));;
		g|G) out=$((out*1073741824 ));;
		t|T) out=$((out*1073741824*1024));;
		*) :;;
	esac
	echo "$out"
}
