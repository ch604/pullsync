multihomedir_check() { #multiple homedirs check
	! grep -q ^HOMEMATCH\  /etc/wwwacct.conf && localhomedir=$(awk '/^HOMEDIR / {print $2}' /etc/wwwacct.conf) || localhomedir=$(find / -maxdepth 1 -type d | grep $(awk '/^HOMEMATCH / {print $2}' /etc/wwwacct.conf))
	! grep -q ^HOMEMATCH\  $dir/etc/wwwacct.conf && remotehomedir=$(awk '/^HOMEDIR / {print $2}' $dir/etc/wwwacct.conf) || remotehomedir=$(sssh "find / -maxdepth 1 -type d" | grep $(awk '/^HOMEMATCH / {print $2}' $dir/etc/wwwacct.conf))

	if ! [[ "$synctype" == "prefinal" || "$synctype" == "final" || "$synctype" == "update" || "$synctype" == "homedir" ]]; then
		if [ $(echo $remotehomedir | wc -w) = 1 ]; then
			ec yellow "There is only one homedir in use on the remote server: $remotehomedir"
		else
			ec yellow "There are multiple homedirs in use on the remote server: $(echo $remotehomedir | tr '\n' ' ')"
		fi
		if [ $(echo $localhomedir | wc -w) = 1 ]; then
			ec yellow "There is only one homedir in use on the local server: $localhomedir"
			ec green "If restoring accounts, they will of course all go to this homedir."
		else
			ec yellow "There are multiple homedirs in use on the local server: $(echo $localhomedir | tr '\n' ' ')"
			ec red "If restoring accounts, WHM will choose a homedir based on free space!"
		fi
	fi
}
