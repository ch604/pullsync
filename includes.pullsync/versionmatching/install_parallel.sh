install_parallel() { #build parallel and set will-cite to keep commands unattended
	# make sure /usr/local/bin is in the path
	! echo $PATH | grep -q /usr/local/bin && export PATH=$PATH:/usr/local/bin
	if [ ! `which parallel 2> /dev/null` ]; then
		# parallel not installed, build it now
		ec yellow " GNU parallel..."
		mkdir -p /usr/local/src
		pushd /usr/local/src 2>&1 | stderrlogit 4
		# get the latest public version if ftp.gnu.org is up, otherwise use files.lw
		if (timeout 1 bash -c 'echo > /dev/tcp/ftp.gnu.org/80') &> /dev/null; then
			wget -q http://ftp.gnu.org/gnu/parallel/parallel-latest.tar.bz2 -O parallel-latest.tar.bz2
		else
			wget -q http://files.liquidweb.com/migrations/pullsync/parallel-latest.tar.bz2 -O parallel-latest.tar.bz2
		fi
		tar -jxf parallel-latest.tar.bz2
		cd parallel* || (
			ec red "Parallel failed to extract during install!"
			exitcleanup 70
		)
		(./configure && make && make install) 2>&1 | stderrlogit 4
		# get rid of the 'cite' warning on execution
		mkdir -p /root/.parallel; touch /root/.parallel/will-cite
		popd 2>&1 | stderrlogit 4
	elif [ ! -e /root/.parallel/will-cite ]; then
		# if already installed, touch the 'cite' file anyway just to be sure
		mkdir -p /root/.parallel; touch /root/.parallel/will-cite
	fi
	[ ! `which parallel 2> /dev/null` ] && ec red "Parallel failed to install! Make sure you can execute 'parallel' and 'sem' before restarting the script. Exiting..." && exitcleanup 70
}
