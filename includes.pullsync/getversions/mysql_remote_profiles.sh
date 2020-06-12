mysql_remote_profiles() { #check for remote profiles on both servers
	# perform a bunch of python to parse the json files and determine if there are additionl mysql profiles
	if [ -s $dir/var/cpanel/mysql/remote_profiles/profiles.json ] && cat $dir/var/cpanel/mysql/remote_profiles/profiles.json | python -c 'import sys,json; hosts=json.load(sys.stdin).keys(); print "\n".join(hosts)' | grep -vq localhost; then #see if there are any non-localhost mysql profiles
		remoteactiveprofile=$(for host in $(cat $dir/var/cpanel/mysql/remote_profiles/profiles.json | python -c 'import sys,json; hosts=json.load(sys.stdin).keys(); print "\n".join(hosts)'); do active=$(cat $dir/var/cpanel/mysql/remote_profiles/profiles.json | python -c 'import sys,json; active=json.load(sys.stdin); print (active["'$host'"]["active"])'); echo "$host $active"; done | grep 1$ | awk '{print $1}')
		if [ ! "$remoteactiveprofile" = "localhost" ]; then
			ec red "Remote server has non-localhost mysql profiles and may be using a remote database server (with a profile named \"$remoteactiveprofile\"). This is normally not a problem, just wanted to let you know."
		fi
	fi
	# do the same on target server
	if [ -s /var/cpanel/mysql/remote_profiles/profiles.json ] && cat /var/cpanel/mysql/remote_profiles/profiles.json | python -c 'import sys,json; hosts=json.load(sys.stdin).keys(); print "\n".join(hosts)' | grep -vq localhost; then
		localactiveprofile=$(for host in $(cat /var/cpanel/mysql/remote_profiles/profiles.json | python -c 'import sys,json; hosts=json.load(sys.stdin).keys(); print "\n".join(hosts)'); do active=$(cat /var/cpanel/mysql/remote_profiles/profiles.json | python -c 'import sys,json; active=json.load(sys.stdin); print (active["'$host'"]["active"])'); echo "$host $active"; done | grep 1$ | awk '{print $1}')
		if [ ! "$localactiveprofile" = "localhost" ]; then
			ec red "Local server has non-localhost mysql profiles and may be using a remote database server (with a profile named \"$localactiveprofile\"). This is normally not a problem, just wanted to let you know."
		fi
	fi
	# throw a big flag if both servers have remote mysql
	if [ "$remoteactiveprofile" ] && [ "$localactiveprofile" ] && [ ! "$remoteactiveprofile" = "localhost" ] && [ ! "$localactiveprofile" = "localhost" ]; then
		ec lightRed "I think that both servers are using remote mysql. If they are using the same remote mysql host, THIS IS A BIG PROBLEM. STOP HERE AND INVESTIGATE."
		say_ok
	fi
}
