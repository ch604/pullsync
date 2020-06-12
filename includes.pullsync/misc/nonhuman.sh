nonhuman() { #remove human readable suffixes from variables like 64M, used for comparing php settings
	out=$(echo $1 | tr -d '[a-zA-Z]')
	suffix=$(echo $1 | tr -d '[0-9B]')
	case $suffix in
		k|K) out=$(( $out * 1024 ));;
		m|M) out=$(( $out * 1048576 ));;
		g|G) out=$(( $out * 1073741824 ));;
		*) :;;
	esac
	echo $out
}
