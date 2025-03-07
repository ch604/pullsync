cloudlinux_check() {
	# see if remote server is cloudlinux
	echo $remote_os | grep -q ^Cloud && ec lightRed "CloudLinux detected on remote server." && say_ok
	if echo $local_os | grep -q ^Cloud; then
		# make sure all of the CL programs are present
		ec yellow "CloudLinux detected on local server. Confirming extras are installed..."
		uname -r | grep -q lve; [ ! $? -eq 0 ] && ec lightRed " CLOUDLINUX KERNEL NOT RUNNING! detected $(uname -r) which doesnt say 'lve'." | tee -a $dir/missingclstuff.txt
		[ ! -x /usr/sbin/cagefsctl ] && ec lightRed " cagefs missing!" | tee -a $dir/missingclstuff.txt
		! rpm -q --quiet lvemanager && ec lightRed " lvemanager missing!" | tee -a $dir/missingclstuff.txt
		[ -f /etc/cpanel/ea4/is_ea4 ] && ! rpm -q --quiet cloudlinux-ea4-release && ec lightRed " ea4 hook rpm (cloudlinux-ea4-release) missing!" | tee -a $dir/missingclstuff.txt
		service db_governor status 2>&1 | stderrlogit 4; [ ! ${PIPESTATUS[0]} -eq 0 ] && ec lightRed " mysql governor missing!" | tee -a $dir/missingclstuff.txt
		[ ! -x /usr/bin/selectorctl ] && ec lightRed " alt-php missing!" | tee -a $dir/missingclstuff.txt
		[ -s $dir/missingclstuff.txt ] && ec lightRed "Some CloudLinux items are missing! Please fix the errors noted if necessary. (cat $dir/missingclstuff.txt)" | errorlogit 3 && say_ok
	fi
}
