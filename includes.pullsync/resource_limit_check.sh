resource_limit_check() { # determine if any oom, maxconn, or mysql 'too many connections' limits were hit per logs.
	ec yellow "Checking for resource limit hits on source server..."
	local oom_hits=$(sssh "grep -i oom-killer /var/log/messages 2> /dev/null")
	local mc_hits=$(sssh "grep -i MaxClients /usr/local/apache/logs/error_log")
	local cnxn_hits=$(sssh "grep -i 'too many connections' /usr/local/apache/logs/error_log")
	if [ "$oom_hits" ]; then
		ec red "Source server ran OOM killer in the past!" | errorlogit 3 root
		echo "$oom_hits" | tee -a $dir/resource_oom.txt | tail -n10
		say_ok
	fi
	if [ "$mc_hits" ]; then
		ec red "Source server hit MaxClients in the past!" | errorlogit 3 root
		echo "$mc_hits" | tee -a $dir/resource_mc.txt | tail -n10
		say_ok
	fi
	if [ "$cnxn_hits" ]; then
		ec red "Source server hit MaxConnections for mysql in the past!" | errorlogit 3 root
		echo "$cnxn_hits" | tee -a $dir/resource_cnxn.txt | tail -n10
		say_ok
	fi
}
