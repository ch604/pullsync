multihomedir_check() { #multiple homedirs check
	localhomedir=$(whmapi1 --output=json get_homedir_roots | jq -r '.data.payload[].path')
	remotehomedir=$(sssh "whmapi1 --output=json get_homedir_roots" | jq -r '.data.payload[].path')

	if ! echo -e "prefinal\nfinal\nupdate\nhomedir" | grep -qx "$synctype"; then
		if [ "$(wc -w <<< "$remotehomedir")" = 1 ]; then
			ec yellow "There is only one homedir in use on the remote server: $remotehomedir"
		else
			ec yellow "There are multiple homedirs in use on the remote server: $remotehomedir"
		fi
		if [ "$(wc -w <<< "$localhomedir")" = 1 ]; then
			ec yellow "There is only one homedir in use on the local server: $localhomedir"
			ec green "If restoring accounts, they will of course all go to this homedir."
		else
			ec yellow "There are multiple homedirs in use on the local server: $localhomedir"
			ec red "If restoring accounts, WHM will choose a homedir based on free space!"
		fi
	fi
}
