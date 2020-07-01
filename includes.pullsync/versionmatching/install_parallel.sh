install_parallel() { #build parallel and set will-cite to keep commands unattended
	if [ ! `which parallel 2> /dev/null` ]; then
		# parallel not installed, build it now
		ec yellow " GNU parallel..."
		[ ! "$(yum -q provides parallel)" ] && yum -y -q install epel-release
		yum -y -q install parallel
		# get rid of the 'cite' warning on execution
		mkdir -p /root/.parallel
		touch /root/.parallel/will-cite
	elif [ ! -e /root/.parallel/will-cite ]; then
		# if already installed, touch the 'cite' file anyway just to be sure
		mkdir -p /root/.parallel
		touch /root/.parallel/will-cite
	fi
	[ ! `which parallel 2> /dev/null` ] && ec red "Parallel failed to install! Make sure you can execute 'parallel' and 'sem' before restarting the script. Exiting..." && exitcleanup 70
}
