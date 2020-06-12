cpnat_check() { # if the server has a natted primary IP per the natprefix variable in variables.sh, build cpnat if needed
	if [ ! "$synctype" = "single" ]; then
		# only check on non-single migrations, in case of shared target
		natcheck=`echo $cpanel_main_ip | grep -E "^($natprefix)"`
		if [ ! "$natcheck" = "" ]; then
			# ensure cpnat exists, build if not
			if [ ! -f /var/cpanel/cpnat ]; then
				ec red "Natted primary IP detected, but /var/cpanel/cpnat not built! Building now..." | errorlogit 4
				/scripts/build_cpnat
			else
				ec green "Natted primary IP detected, and /var/cpanel/cpnat already built."
			fi
		fi
	fi
}
