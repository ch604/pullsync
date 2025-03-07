resellercheck() { #check for resellers in $userlist, place in a separate file so they will restore before any other accounts
	if [ -s $dir/var/cpanel/resellers ]; then
		ec yellow "Detected resellers! Reordering userlist..."
		resellers=$(cut -d: -f1 $dir/var/cpanel/resellers)
		echo $userlist > $dir/nonresellers.txt
		realresellers=""
		for i in $resellers; do
			check=$(grep -E '(\ |^)$i(\ |$)' $dir/nonresellers.txt)
			if [[ $check != "" ]]; then
				sed -i "s/\(^\|\s\)$i\($\|\s\)/ /g" $dir/nonresellers.txt
				realresellers="$realresellers $i"
			fi
		done
		userlist="$realresellers $(cat $dir/nonresellers.txt)"
		echo $realresellers > $dir/realresellers.txt
	fi
}
