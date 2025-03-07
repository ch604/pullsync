fixpermscheck() {
	local user userhome_remote
	user=$1
	userhome_remote=$(awk -F: '/^'$user':/ {print $6}' $dir/etc/passwd)
	[[ ! "$(sssh "stat /home/$user/public_html 2> /dev/null" | awk -F'[(|/|)]' '/Uid/ {print $2, $6, $9}')" =~ 0?75[01]\ +$user\ +(nobody|$user) ]] && return 1
	return 0
}