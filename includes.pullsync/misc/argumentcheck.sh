argumentcheck() { # scan for command line options
	while getopts :t:u:i:p:k:mhserdl:xy opt; do
		case $opt in
			h) displayhelp && exitcleanup 9 ;;
			i) ip=$OPTARG ;;
			p) port=$OPTARG ;;
			k) keyfile=$OPTARG ;;
			u) lwuser=$OPTARG ;;
			t) synctype=$OPTARG ;;
			x) malwarescan=1 ;;
			y) runmarill=1 ;;
			m) do_installs=1 ;;
			l) echo "$OPTARG" > $dir/whmcontact.txt ; setcontact=1;;
			s) stopservices=1 ;;
			e) maintpage=1 ;;
			r) restartservices=1 ;;
			d) copydns=1 ;;
			\?) echo "Invalid option: -$OPTARG" && exitcleanup 9 ;;
			:) echo "Option -$OPTARG requires an argument!" && exitcleanup 9 ;;
		esac
	done

	if [ "$ip" -o "$synctype" ]; then
		autopilot=1
		[ ! "$ip" ] && echo "-i is a required option!" && exitcleanup 9
		[[ ! $ip =~ $valid_ip_format ]] && echo "$ip doesnt look like a valid IP!" && exitcleanup 9
		[ ! "$port" ] && port=22
		[[ ! $port =~ $valid_port_format ]] && echo "$port doesnt look like a valid port!" && exitcleanup 9
		[ ! "$keyfile" ] && echo "-k is a required option!" && exitcleanup 9
		[ "$keyfile" ] && ! grep -q BEGIN\ [RD]SA\ PRIVATE\ KEY $keyfile && echo "$keyfile doesnt look like a private key!" && exitcleanup 9
		case $synctype in
			final) unset do_installs runmarill; removemotd=1 ;;
			all|list) unset stopservices maintpage restartservices copydns ;;
			"") echo "-t is a required option!" && exitcleanup 9 ;;
			*) echo "Invalid synctype: $synctype" && exitcleanup 9 ;;
		esac
	else
		unset ip port lwuser synctype do_installs stopservices maintpage restartservices copydns malwarescan runmarill
		ec red "You didn't pass enough arguments!"
		exitcleanup 9
	fi
}
