parallel_usercollide() {
	local user
	user=$1
	if [ -f "/var/cpanel/users/$user" ] && echo -e "single\nlist\ndomainlist\nall\nskeletons" | grep -qx "$synctype"; then # if the user exists for an initial sync, exit.
		ec lightRed  "Error: $user already exists on this server" | errorlogit 1 root
		echo "$user" >> "$dir/conflicts.txt"
		touch "$dir/collision_encountered"
	elif [ ! -f "$dir/var/cpanel/users/$user" ]; then # if the user selected does not exist on source server, exit
		ec lightRed "Error: $user was selected for a sync, but does not exist on source server!" | errorlogit 1 root
		echo "$user" >> "$dir/conflicts.txt"
		touch "$dir/collision_encountered"
	elif [ ! -f "/var/cpanel/users/$user" ] && echo -e "final\nprefinal\nupdate\nhomedir\nmysql\npgsql\nemail\nemaillist" | grep -qx "$synctype"; then # if the user does not exist for a final/update sync, exit
		ec lightRed "Error: Selected user $user does not exist on this server!" | errorlogit 1 root
		echo "$user" >> "$dir/conflicts.txt"
		touch "$dir/collision_encountered"
	fi
}
