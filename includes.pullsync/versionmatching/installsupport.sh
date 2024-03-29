installsupport() { #make sure all of the functions necessary to run pullsync are installed
	ec yellow "Installing supporting functions..."
	# rpms
	for program in dialog whois git virt-what bc gem; do
		if [ ! $(which $program 2> /dev/null) ]; then
			ec yellow " $program..."
			yum -y -q --skip-broken install $(yum -q provides $program | grep -e x86_64 -e noarch | tail -1 | awk '{print $1}') 2>&1 | stderrlogit 3
		fi
	done
	# parallel
	install_parallel
	# this line ensures that cpan default settings are in place when running cpan -l
	true | cpan -v &> /dev/null
	if ! cpan -l 2> /dev/null | grep -q ^URI\:\:Escape; then
		# uri::escape not installed
		ec yellow " URI::Escape..."
		/usr/local/cpanel/bin/cpanm URI::Escape -n 2>&1 | stderrlogit 3
	fi
	# pyyaml for yaml file analysis
	pip_and_pyyaml
	# python
	if [ ! $(which python 2> /dev/null) ]; then
		if [ $(which python3 2> /dev/null) ]; then
			ln -s $(which python3) /usr/bin/python
		elif [ $(which python3.9 2> /dev/null) ]; then
			ln -s $(which python3.9) /usr/bin/python
		elif [ $(which python2 2> /dev/null) ]; then
			ln -s $(which python2) /usr/bin/python
		elif [ $(which python2.7 2> /dev/null) ]; then
			ln -s $(which python2.7) /usr/bin/python
		else
			ec yellow " python..."
			yum -y -q --skip-broken install $(yum -q provides python3 | grep -e x86_64 -e noarch | tail -1 | awk '{print $1}') 2>&1 | stderrlogit 3
			[ ! $(which python 2> /dev/null) ] && ln -s $(which python3) /usr/bin/python
		fi
	fi
	# quit if critical items still arent installed
	for program in dialog whois git virt-what bc gem python; do
		if [ ! $(which $program 2> /dev/null) ]; then
			ec red "It looks like yum might not be working... try 'yum clean all && rpm --rebuilddb && yum update' before retrying this script!"
			exitcleanup 70
		fi
	done
}
