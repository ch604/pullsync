nsprog_check() { # local nameserver setting check
	local sourcenstype localnstype source_nameservers local_nameservers
	if [ ! "$synctype" = "single" ] ;then
		# on non-single migrations, compare nameserver settings
		ec yellow "Source server nameserver settings:"
		source_nameservers=$(grep "^NS[ 0-9]" "$dir/etc/wwwacct.conf" | grep -vE "NS[ 0-9][ ]?$" | sort)
		echo "$source_nameservers" | logit
		ec yellow "Local nameserver settings:"
		local_nameservers=$(grep "^NS[ 0-9]" /etc/wwwacct.conf | grep -vE "NS[ 0-9][ ]?$" | sort)
		echo "$local_nameservers" | logit
		if [ ! "$source_nameservers" = "$local_nameservers" ]; then
			if [ ! "$autopilot" ]; then
				if yesNo "Change local namservers to match source values?"; then
					sed -i -e '/^NS[\ 0-9]/d' /etc/wwwacct.conf
					echo "$source_nameservers" >> /etc/wwwacct.conf
				fi
			elif [ "$autopilot" ] && [ "$do_installs" ]; then
				sed -i '/^NS[\ 0-9]/d' /etc/wwwacct.conf
				echo "$source_nameservers" >> /etc/wwwacct.conf
			fi
		else
			ec green "Nameservers match"
		fi

		# check the nameserver binary
		if sssh "[ ! -x /scripts/setupnameserver ]"; then
			sourcenstype=bind
		else
			sourcenstype=$(sssh "/scripts/setupnameserver --current" | awk '{print $4}')
		fi
		localnstype=$(/scripts/setupnameserver --current | awk '{print $4}')
		if [ ! "$localnstype" = "$sourcenstype" ] ; then
			ec yellow "Source server nameserver type:"
			echo "$sourcenstype" | logit
			ec yellow "Local server nameserver type:"
			echo "$localnstype" | logit
			ec white "Nameserver type will be matched if WHM tweak settings are copied."
			say_ok
		fi
	fi
}
