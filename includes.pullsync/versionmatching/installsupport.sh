installsupport() { #make sure all of the functions necessary to run pullsync are installed
	ec yellow "Installing supporting functions..."
	# dialog, whois, git, virt-what, bh
	[ ! `which dialog 2> /dev/null` ] || [ ! `which git 2> /dev/null` ] || [ ! `which whois 2> /dev/null` ] || [ ! `which virt-what 2> /dev/null` ] || [ ! `which bc 2> /dev/null` ] && ec yellow " RPMs..." && yum -y install dialog jwhois whois git virt-what bc --skip-broken 2>&1 | stderrlogit 3
	# parallel
	install_parallel
	# this line ensures that cpan default settings are in place when running cpan -l
	true | cpan -v 2>&1 > /dev/null
	if ! cpan -l 2> /dev/null | grep -q URI\:\:Escape; then
		# uri::escape not installed
		ec yellow " URI::Escape..."
		/usr/local/cpanel/bin/cpanm URI::Escape -n 2>&1 | stderrlogit 3
	fi
	# pyyaml for yaml file analysis
	pip_and_pyyaml
	# quit if critical items still arent installed
	if [ ! `which dialog 2> /dev/null` ] || [ ! `which git 2> /dev/null` ] || [ ! `which whois 2> /dev/null` ] || [ ! `which virt-what 2> /dev/null` ] || [ ! `which bc 2> /dev/null` ]; then
		ec red "It looks like yum might not be working... try 'yum clean all && rpm --rebuilddb && yum update' before retrying this script!"
		exitcleanup 70
	fi
}
