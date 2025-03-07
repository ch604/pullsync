human() { #make a long number in bytes human readable with two significant digits
	local bytes decimal index SI
	bytes=${1:-0}
	decimal=''
	index=0
	SI=(Bytes {K,M,G,T,E,P,Y,Z}B)
	while ((bytes > 1024)); do
		decimal="$(printf ".%02d" $((bytes % 1024 * 100 / 1024)))"
		bytes=$((bytes / 1024))
		((index++))
	done
	echo "$bytes$decimal${SI[$index]}"
}
