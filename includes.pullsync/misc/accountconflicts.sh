accountconflicts() { #called by getuserlist, make sure there are no collisions with existing accounts
	ec yellow "Checking for account conflicts..."
	for user in $userlist ; do
		if [ -f "/var/cpanel/users/$user" ] && [[ "$synctype" =~ "single" || "$synctype" == "list" || "$synctype" =~ "domainlist" || "$synctype" =~ "all" ]]; then # if the user exists for an initial sync, exit.
			ec lightRed  "Error: $user already exists on this server" | errorlogit 1
			echo $user >> $dir/conflicts.txt
			error_encountered=1
		elif [ ! -f "$dir/var/cpanel/users/$user" ]; then # if the user selected does not exist on source server, exit
			ec lightRed "Error: $user was selected for a sync, but does not exist on source server!" | errorlogit 1
			echo $user >> $dir/conflicts.txt
			error_encountered=1
		elif [ ! -f "/var/cpanel/users/$user" ] && [[ "$synctype" =~ "final" || "$synctype" == "update" || "$synctype" == "homedir" || "$synctype" == "mysql" || "$synctype" == "pgsql" || "$synctype" =~ "email" ]]; then # if the user does not exist for a final/update sync, exit
			ec lightRed "Error: Selected user $user does not exist on this server!" | errorlogit 1
			echo $user >> $dir/conflicts.txt
			error_encountered=1
		fi
	done

	if [[ "$synctype" == "single" || "$synctype" == "list" || "$synctype" == "domainlist" || "$synctype" == "all" ]]; then
		ec yellow "Checking for domain conflicts..."
		for dom in $domainlist; do
			#if the domain being migrated is already owned, exit
			if grep -q ^$dom\:\  /etc/userdatadomains; then
				ec lightRed "Error: Domain $dom already exists on this server! (owned by $(awk -F": |==" '/^'$dom': / {print $2}' /etc/userdatadomains))" | errorlogit 1
				echo $dom >> $dir/conflicts.dom.txt
				error_encountered=1
			fi
		done

		ec yellow "Checking for license limits..."
		local target_usercount=$(\ls -A /var/cpanel/users/ | egrep -v "^HASH" | egrep -vx "${badusers}" | wc -w)
		local licensetype=$(awk '/"center">cPanel / {print $3}' $dir/validate_license_output.txt)
		local licenselimit=0
		case $licensetype in
			"Admin") licenselimit=5;;
			"Pro") licenselimit=30;;
			"Plus") licenselimit=50;;
			"Premier") licenselimit=$(awk -F" |<" '/"center">cPanel / {print $6}' $dir/validate_license_output.txt);;
			"") :;; #old license type, unlimited, will skip rest of check
			*) :;; #includes 'autoscale' and 'development'
		esac
		if [ ! $licenselimit = 0 ] && [ $(($licenselimit - $target_usercount)) -lt $(echo $userlist | wc -w) ]; then
			ec lightRed "You will go over the cPanel license limit! ($target_usercount existing users plus $(echo $userlist | wc -w) migrated users is more than $licenselimit license limit!)" | errorlogit 1
			exitcleanup 7
		fi
	fi

	if [[ "$synctype" =~ "final" || "$synctype" == "update" ]]; then #matches final and prefinal
		ec yellow "Checking for excess users..."
		for each in $userlist; do
			if [ ! "$(\ls /var/cpanel/users/$each 2> /dev/null)" ]; then
				ec lightRed "Error: $each was selected for a final sync, but does not exist on target!"
				echo $each >> $dir/finaluserremoved.txt
				final_target_user_missing=1
			fi
		done
		ec yellow "Checking for unsynced items..."
		ec yellow " Users..."
		for each in $(\ls -A $dir/var/cpanel/users/ | egrep -v "^HASH" | egrep -vx "${badusers}"); do
			#ensure all accounts on source are in userlist
			if ! echo $userlist | tr ' ' '\n' | grep -q -x $each; then
				ec lightRed "Error: $each exists on source, but is not in userlist!" | errorlogit 2
				echo $each >> $dir/missingaccounts.txt
				final_account_missing=1
			fi
		done
		ec yellow " Domains..."
		for dom in $(for user in $userlist; do awk -F= '/^DNS.*=/ {print $2}' $dir/var/cpanel/users/$user; done); do
			#ensure all domains bieing migrated have owners
			if [ ! "$(/scripts/whoowns $dom)" ]; then
				local sourceuser=$(grep -l ^DNS.*=${dom} $dir/var/cpanel/users/* | awk -F\/ '{print $NF}')
				ec lightRed "Error: $dom exists on source but not target (owned by source user $sourceuser)" | errorlogit 2
				echo "$dom (belongs to $sourceuser)" >> $dir/missingaccounts.txt
				final_account_missing=1
			fi
		done
#		ec yellow " Zonefile changes..."
#		for dom in $(for user in $userlist; do awk -F= '/^DNS.*=/ {print $2}' $dir/var/cpanel/users/$user; done); do
#			#test zonefiles for differences, skipping serial number, nameserver lines, and anything adjusted to the new IP
#			if [ "$(diff -q -I Serial\ Number -I NS -I $(grep ^${dom}\: /etc/userdatadomains | awk -F'==|:' '{print $9}') /var/named/$dom.db $dir/var/named/$dom.db)" ]; then
#				local sourceuser=$(grep -l ^DNS.*=${dom} $dir/var/cpanel/users/* | awk -F\/ '{print $NF}')
#				ec lightRed "Error: $dom zonefile is different on source from target (owned by source user $sourceuser)" | errorlogit 2
#				diff -I Serial\ Number -I $(grep ^${dom}\: /etc/userdatadomains | awk -F'==|:' '{print $9}') /var/named/$dom.db $dir/var/named/$dom.db
#				echo "$dom (belongs to $sourceuser) zonefile changes" >> $dir/missingaccounts.txt
#				final_account_missing=1
#			fi
#		done
	fi

	#if there were any collisions, record details and bail
	if [ "$error_encountered" ]; then
		ec red "Conflicts found, put conflicting users in $dir/conflicts.txt and domains in $dir/conflicts.dom.txt." | errorlogit 1
		ec yellow "Placing additional details in $dir/conflict_details.txt..."
		(
		hostname
		grep ^'ADDR ' /etc/wwwacct.conf
		[ -f $dir/conflicts.txt ] && for cpuser in $(cat $dir/conflicts.txt 2> /dev/null); do
			echo -e "\n----------\n#${cpuser}\n#accounting.log:"
			grep :${cpuser}$ /var/cpanel/accounting.log
			echo -e "\n#userdatadomains:"
			grep ': '${cpuser}== /etc/userdatadomains | awk -F": |==" ' {print $1,$2,$7}'
			echo -e "\n#DNS:"
			for i in $(egrep ': '${cpuser}$ /etc/userdomains | sort | sed -n 's/:.*//;/\*/!p'); do
				echo -e \\t $i\\t $(echo $(dig @8.8.8.8 NS +short $i | sed 's/\.$//g' | tail -2 | sort)\ $(dig @8.8.8.8 +short $i | grep -v [a-zA-Z] | tail -1) | grep -v \ \  | column -t )\\n\\t $(echo \#MX:\ $(dig MX $i | egrep '^[a-zA-Z0-9].*(MX|A)' | awk '{print $NF}') | sed -e 's/  / /g' | column -t)\\n
			done
		done
		[ -f $dir/conflicts.dom.txt ] && for dom in $(cat $dir/conflicts.dom.txt 2> /dev/null); do
			echo -e "\n----------\n#${dom}\n#accounting.log:"
			grep :${dom}: /var/cpanel/accounting.log
			echo -e "\n#userdatadomains:"
			grep ^${dom}\:\  /etc/userdatadomains | awk -F": |==" ' {print $1,$2,$7}'
			echo -e "\n#DNS:"
			echo -e \\t $dom\\t $(echo $(dig @8.8.8.8 NS +short $dom | sed 's/\.$//g' | tail -2 | sort)\ $(dig @8.8.8.8 +short $dom | grep -v [a-zA-Z] | tail -1) | grep -v \ \  | column -t )\\n\\t $(echo \#MX:\ $(dig MX $dom | egrep '^[a-zA-Z0-9].*(MX|A)' | awk '{print $NF}') | sed -e 's/  / /g' | column -t)\\n
		done
		) > $dir/conflict_details.txt
		ec lightRed "There were $(cat $dir/conflicts.txt | wc -l) user conflicts and $(cat $dir/conflicts.dom.txt | wc -l) domain conflicts."
		ec lightRed "Resolve conflicts (cat $dir/conflict_details.txt) and re-run sync!" | errorlogit 1
		exitcleanup 7
	fi

	if [ "$final_target_user_missing" ]; then
		ec red "$(cat $dir/finaluserremoved.txt | wc -l) accounts are in your userlist that DO NOT EXIST ON TARGET! Rescope your userlist and try again! (cat $dir/finaluserremoved.txt)" | errorlogit 1
		exitcleanup 7
	fi

	if [ "$final_account_missing" ]; then
		ec red "$(grep -v \( $dir/missingaccounts.txt | wc -l) accounts and $(grep \( $dir/missingaccounts.txt | wc -l) domains exist on source that do not exist on target or are not in the userlist, or zonefile differences were encountered! (cat $dir/missingaccounts.txt)" | errorlogit 2
		ec red "Hit enter to proceed if this is expected, or Control+C now to bail and migrate/remigrate these users separately!"
		say_ok
	fi
}
