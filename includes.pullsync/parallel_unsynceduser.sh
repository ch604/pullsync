parallel_unsynceduser() { #ensure all accounts on source are in userlist
	user=$1
	if ! echo "$userlist" | tr ' ' '\n' | grep -qx "$user"; then
		ec lightRed "Error: $user exists on source, but is not in userlist!" | errorlogit 2 root
		echo "$each" >> "$dir/missingaccounts.txt"
		touch "$dir/final_account_missing"
	fi
}
