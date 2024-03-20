mysqlcalc() { #calculate (but dont implement) ideal innodb_buffer_pool_size and key_buffer_size for existing dbs. calculations performed in bytes
	ec yellow "Calculating IBPS/KBS..."
	# add up the size of all ibd* files
	local target_ibps=$(find /var/lib/mysql/ -type f -printf "%s %f\n"|awk -F'[ ,.]' '{print $1, $NF}'|sort -k2|awk '{array[$2]+=$1} END {for (i in array) {print array[i]"\t"i}}' | awk '/ibd/ {print $1}' | paste -sd+ - | bc)
	# get the size of all MYI files
	local target_kbs=$(find /var/lib/mysql/ -type f -printf "%s %f\n"|awk -F'[ ,.]' '{print $1, $NF}'|sort -k2|awk '{array[$2]+=$1} END {for (i in array) {print array[i]"\t"i}}' | awk '/MYI/ {print $1}')
	[[ ! $target_kbs ]] && target_kbs=0
	# get the total target memory in comparable format
	local total_mem_bytes=$(( $local_mem * 1048576 ))

	# show results in human readable format, copy into a text file for later
	(ec yellow "Current innodb_buffer_pool_size is $(human $(mysql -Nse 'select @@innodb_buffer_pool_size')), and current key_buffer_size is $(human $(mysql -Nse 'select @@key_buffer_size'))."
	ec yellow "Projected ideal innodb_buffer_pool_size is $(human $target_ibps), and projected ideal key_buffer_size is $(human $target_kbs).") | tee -a $dir/mysql_calc.txt
	if [ $(( $total_mem_bytes / 2 )) -gt $(( $target_ibps + $target_kbs )) ]; then
		ec green "These are less than 50% of the total memory on the server, $(human $total_mem_bytes). You should set the above settings, rounded up, to ensure all DBs are put into memory. (cat $dir/mysql_calc.txt)"
	else
		ec yellow "These are more than 50% of the total memory on the server, $(human $total_mem_bytes). You should more closely evaluate mysql settings for best memory usage. (cat $dir/mysql_calc.txt)"
	fi
}
