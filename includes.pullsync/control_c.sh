control_c() { #if control_c is pushed, attempt to clean up
	echo -e "\nControl-C pushed, exiting..." | errorlogit 1 root
	# try to kill bg jobs
	# shellcheck disable=SC2046
	[ "$(jobs -pr)" ] && kill $(jobs -pr) && sleep 1
	# reset tty
	stty sane
	# enable panic/reboot on oom if we hit control-c during final sync
	[ "$(sysctl -n vm.panic_on_oom)" -eq 0 ] && sysctl vm.panic_on_oom=1 &> /dev/null
	exitcleanup 130
}
