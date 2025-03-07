parallel_domcollide() {
	dom=$1
	#if the domain being migrated is already owned, throw error
	if grep -q "^$dom: " /etc/userdatadomains; then
		ec lightRed "Error: Domain $dom already exists on this server! (owned by $(awk -F": |==" '/^'"$dom"': / {print $2}' /etc/userdatadomains))" | errorlogit 1 root
		echo "$dom" >> "$dir/conflicts.dom.txt"
		touch "$dir/collision_encountered"
	fi
}
