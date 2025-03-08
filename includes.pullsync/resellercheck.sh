resellercheck() { #check for resellers in $userlist. the files are written for posterity; ordering the userlist appropriately is generally sufficient for proper restore order.
	if [ -s "$dir/var/cpanel/resellers" ]; then
		ec yellow "Detected resellers! Reordering userlist..."
		allresellers=$(cut -d: -f1 $dir/var/cpanel/resellers)
		echo $userlist > $dir/nonresellers.txt
		resellers=""
		for i in $allresellers; do
			if grep -qE '(\ |^)'$i'(\ |$)' $dir/nonresellers.txt; then
				sed -i "s/\(^\|\s\)$i\($\|\s\)/ /g" $dir/nonresellers.txt
				resellers="$resellers $i"
			fi
		done
		if [ "$(echo $resellers | wc -w)" -ge 1 ]; then
			userlist="$resellers $(cat $dir/nonresellers.txt)"
			echo $resellers > $dir/resellers.txt
		fi
	fi
}
