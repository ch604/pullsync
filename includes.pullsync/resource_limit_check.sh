resource_limit_check() { # determine if any oom, maxconn, or mysql 'too many connections' limits were hit per logs.
	local oom_hits mc_hits cnxn_hits
	ec yellow "Checking for resource limit hits on source server..."
	oom_hits=$(sssh "grep -i oom-killer /var/log/messages 2> /dev/null")
	mc_hits=$(sssh "grep -i MaxClients /usr/local/apache/logs/error_log")
	cnxn_hits=$(sssh "grep -i 'too many connections' /usr/local/apache/logs/error_log")
	if [ "$oom_hits" ]; then
		ec red "Source server ran OOM killer in the past!" | errorlogit 3 root
		echo "$oom_hits" | tee -a $dir/resource_oom.txt | tail
		say_ok
	fi
	if [ "$mc_hits" ]; then
		ec red "Source server hit MaxClients in the past!" | errorlogit 3 root
		echo "$mc_hits" | tee -a $dir/resource_mc.txt | tail
		say_ok
	fi
	if [ "$cnxn_hits" ]; then
		ec red "Source server hit MaxConnections for mysql in the past!" | errorlogit 3 root
		echo "$cnxn_hits" | tee -a $dir/resource_cnxn.txt | tail
		say_ok
	fi
}
