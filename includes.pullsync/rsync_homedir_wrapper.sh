rsync_homedir_wrapper() { #for final/homedir syncs, splits up the parallel user jobs into rsync semaphores
	local user=$2
	sem --id "datamove$user" -j 2 -u rsync_homedir "$user" "$1/$user_total"
	sem --id "datamove$use"r -j 2 -u rsync_email "$user" "${maildelete:-0}"
	sem --wait --id "datamove$user"
	echo "$user" >> "$dir/final_complete_users.txt"
}
