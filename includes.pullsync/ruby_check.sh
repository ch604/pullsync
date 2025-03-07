ruby_check() { # check for running ruby processes. /bin/ruby will also match /usr/local/bin/ and /usr/bin/
	if sssh "grep -q /bin/ruby /proc/*/environ 2> /dev/null"; then
		ec red "Some processes on the source server are executing ruby, indicating some sites may be using rails or passenger! Please be aware of this while matching gems/versions! Commands:"
		for pid in $(sssh "grep /bin/ruby /proc/*/environ" | tr "/" "\n" | egrep [0-9]); do
			sssh "ps -p $pid -o command=" | logit
		done
		say_ok
	fi
}
