sanitize_dblist() { #remove bad dbs from restore list, as well as anything manually excluded
	# grep away bad dbs and unneeded temporary dbs
	dblist_restore=$(echo "$dblist_restore" | sort -u | grep -Ev -e "^(${baddbs})$" -e "^logaholicDB" -e "^cptmpdb" -e "^$" -e "\*")
	[ -f /root/db_exclude.txt ] && dblist_restore=$(echo "$dblist_restore" | grep -vx -f /root/db_exclude.txt) && ec red "Excluded dbs from /root/db_exclude.txt. Sync these manually later if necessary:" && cat /root/db_exclude.txt | logit
}
