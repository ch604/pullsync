accountconflicts() { #called by getuserlist, make sure there are no collisions with existing accounts
	local target_usercount licensetype licenselimit
	ec yellow "Checking for account conflicts..."
	# shellcheck disable=SC2086
	parallel -j 100% 'parallel_usercollide {}' ::: $userlist

	if echo -e "single\nlist\ndomainlist\nall\nskeleton" | grep -qx "$synctype"; then
		ec yellow "Checking for domain conflicts..."
		# shellcheck disable=SC2086
		parallel -j 100% 'parallel_domcollide {}' ::: $domainlist

		ec yellow "Checking for license limits..."
		target_usercount=$(find /var/cpanel/users/ -maxdepth 1 -type f -printf "%f\n" | grep -Ev "^HASH" | grep -cEvx "${badusers}")
		licensetype=$(awk '/"center">cPanel / {print $3}' "$dir/validate_license_output.txt")
		licenselimit=0
		case $licensetype in
			"Admin") licenselimit=5;;
			"Pro") licenselimit=30;;
			"Plus") licenselimit=50;;
			"Premier") licenselimit=$(awk -F" |<" '/"center">cPanel / {print $(NF-1)}' "$dir/validate_license_output.txt");;
			"") :;; #old license type, unlimited, will skip rest of check
			*) :;; #includes 'autoscale' and 'development'
		esac
		if [ "$licenselimit" -ne 0 ] && [ "$((licenselimit - target_usercount))" -lt "$(wc -w <<< "$userlist")" ]; then
			ec lightRed "You will go over the cPanel license limit! ($target_usercount existing users plus $(wc -w <<< "$userlist") migrated users is more than $licenselimit license limit!)" | errorlogit 1 root
			exitcleanup 7
		fi
	fi

	if echo -e "final\nprefinal\nupdate" | grep -qx "$synctype"; then
		ec yellow "Checking for excess users..."
		for user in $userlist; do
			if [ ! -f "/var/cpanel/users/$user" ]; then
				ec lightRed "Error: $user was selected for a final sync, but does not exist on target!"
				echo "$user" >> "$dir/finaluserremoved.txt"
				final_target_user_missing=1
			fi
		done

		ec yellow "Checking for unsynced items..."
		ec yellow " Users..."
		# shellcheck disable=SC2046
		parallel -j 100% 'parallel_unsynceduser {}' ::: $(find "$dir/var/cpanel/users/" -maxdepth 1 -type f -printf "%f\n" | grep -Ev "^HASH" | grep -Evx "${badusers}")

		ec yellow " Domains..."
		# shellcheck disable=SC2046
		parallel -j 100% 'parallel_unsynceddom {}' ::: $(for user in $userlist; do awk -F= '/^DNS.*=/ {print $2}' "$dir/var/cpanel/users/$user"; done)

#		ec yellow " Zonefile changes..."
#		for dom in $(for user in $userlist; do awk -F= '/^DNS.*=/ {print $2}' $dir/var/cpanel/users/$user; done); do
#			#test zonefiles for differences, skipping serial number, nameserver lines, and anything adjusted to the new IP
#			if [ "$(diff -q -I Serial\ Number -I NS -I $(grep ^${dom}\: /etc/userdatadomains | awk -F'==|:' '{print $9}') /var/named/$dom.db $dir/var/named/$dom.db)" ]; then
#				local sourceuser=$(grep -l ^DNS.*=${dom} $dir/var/cpanel/users/* | awk -F\/ '{print $NF}')
#				ec lightRed "Error: $dom zonefile is different on source from target (owned by source user $sourceuser)" | errorlogit 2 root
#				diff -I Serial\ Number -I $(grep ^${dom}\: /etc/userdatadomains | awk -F'==|:' '{print $9}') /var/named/$dom.db $dir/var/named/$dom.db
#				echo "$dom (belongs to $sourceuser) zonefile changes" >> $dir/missingaccounts.txt
#				final_account_missing=1
#			fi
#		done
	fi

	#if there were any collisions, record details and bail
	if [ -e "$dir/collision_encountered" ]; then
		ec red "Conflicts found, put conflicting users in $dir/conflicts.txt and domains in $dir/conflicts.dom.txt." | errorlogit 1 root
		rm -f "$dir/collision_encountered"
		ec yellow "Placing additional details in $dir/conflict_details.txt..."
		(
		hostname
		grep ^'ADDR ' /etc/wwwacct.conf
		[ -s "$dir/conflicts.txt" ] && while read -r cpuser; do
			echo -e "\n----------\n#$cpuser\n#accounting.log:"
			grep ":${cpuser}$" /var/cpanel/accounting.log
			echo -e "\n#userdatadomains:"
			awk -F": |==" '/: '"$cpuser"'==/ {print $1,$2,$7}' /etc/userdatadomains
			echo -e "\n#DNS:"
			while read -r i; do
				echo -e "\t $i\t $(echo "$(dig @8.8.8.8 NS +short "$i" | sed 's/\.$//g' | tail -2 | sort) $(dig @8.8.8.8 +short "$i" | grep -v "[a-zA-Z]" | tail -1)" | grep -v \ \  | column -t)\n\t $(echo "#MX: $(dig MX "$i" | awk '/^[a-zA-Z0-9].*(MX|A)/ {print $NF}')" | sed 's/  / /g' | column -t)\n"
			done < <(grep ": $cpuser$" /etc/userdomains | sort | sed -n 's/:.*//;/\*/!p')
		done < "$dir/conflicts.txt"
		[ -s "$dir/conflicts.dom.txt" ] && while read -r dom; do
			echo -e "\n----------\n#${dom}\n#accounting.log:"
			grep ":$dom:" /var/cpanel/accounting.log
			echo -e "\n#userdatadomains:"
			awk -F": |==" '/^'"$dom"': / {print $1,$2,$7}' /etc/userdatadomains
			echo -e "\n#DNS:"
			echo -e "\t $dom\t $(echo "$(dig @8.8.8.8 NS +short "$dom" | sed 's/\.$//g' | tail -2 | sort) $(dig @8.8.8.8 +short "$dom" | grep -v "[a-zA-Z]" | tail -1)" | grep -v \ \  | column -t)\n\t $(echo "#MX: $(dig MX "$dom" | awk '/^[a-zA-Z0-9].*(MX|A)/ {print $NF}')" | sed 's/  / /g' | column -t)\n"
		done < "$dir/conflicts.dom.txt"
		) > "$dir/conflict_details.txt"
		ec lightRed "There were $(wc -l < "$dir/conflicts.txt" 2> /dev/null || echo 0) user conflicts and $(wc -l < "$dir/conflicts.dom.txt" 2> /dev/null || echo 0) domain conflicts."
		ec lightRed "Resolve conflicts (cat $dir/conflict_details.txt) and re-run sync!" | errorlogit 1 root
		exitcleanup 7
	fi

	if [ "$final_target_user_missing" ]; then
		ec red "$(wc -l < "$dir/finaluserremoved.txt" 2> /dev/null || echo 0) accounts are in your userlist that DO NOT EXIST ON TARGET! Rescope your userlist and try again! (cat $dir/finaluserremoved.txt)" | errorlogit 1 root
		exitcleanup 7
	fi

	if [ -e "$dir/final_account_missing" ]; then
		ec red "$(grep -cv \( "$dir/missingaccounts.txt") accounts and $(grep -c \( "$dir/missingaccounts.txt") domains exist on source that do not exist on target or are not in the userlist, or zonefile differences were encountered! (cat $dir/missingaccounts.txt)" | errorlogit 2 root
		rm -f "$dir/final_account_missing"
		ec red "Hit enter to proceed if this is expected, or Control+C now to bail and migrate/remigrate these users separately!"
		say_ok
	fi
}