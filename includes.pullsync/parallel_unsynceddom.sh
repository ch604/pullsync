parallel_unsynceddom() { #ensure all domains being migrated have owners
	local sourceuser
	if [ ! "$(/scripts/whoowns "$1")" ]; then
		sourceuser=$(grep -l "^DNS.*=$1" "$dir"/var/cpanel/users/* | awk -F/ '{print $NF}')
		ec lightRed "Error: $1 exists on source but not target (owned by source user $sourceuser)" | errorlogit 2 root
		echo "$1 (belongs to $sourceuser)" >> "$dir/missingaccounts.txt"
		touch "$dir/final_account_missing"
	fi
}
