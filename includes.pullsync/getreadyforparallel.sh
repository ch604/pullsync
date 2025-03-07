getreadyforparallel() {
	ec yellow "Getting ready to run some things in parallel..."
	user_total=$(echo $userlist | wc -w)
	: > $dir/final_complete_users.txt
	prep_for_disk_progress
	echo "$refreshdelay" > $dir/refreshdelay
	ec yellow "Recording mapping files..."
	parallel -j 100% 'record_mapping {}' ::: $userlist
}