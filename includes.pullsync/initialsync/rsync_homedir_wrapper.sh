rsync_homedir_wrapper() { #for final/homedir syncs, generates progress first
	rsync_homedir $2 "$1/$user_total"
}
