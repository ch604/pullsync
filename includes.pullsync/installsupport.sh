installsupport() { #make sure all of the functions necessary to run pullsync are installed
	ec yellow "Installing supporting functions..."
	# repositories
	yum -yq install epel-release 2>&1 | stderrlogit 3 # for lots of different things

	# rpms
	for program in $requireds; do
		if ! rpm -q --quiet $program; then
			ec yellow " $program..."
			yum -yq --skip-broken install $program 2>&1 | stderrlogit 3
		fi
	done

	# python
	if ! which python &> /dev/null; then
		if which python3 &> /dev/null; then
			ln -s "$(which python3)" /usr/bin/python
		elif which python3.9 &> /dev/null; then
			ln -s "$(which python3.9)" /usr/bin/python
		elif which python2 &> /dev/null; then
			ln -s "$(which python2)" /usr/bin/python
		elif which python2.7 &> /dev/null; then
			ln -s "$(which python2.7)" /usr/bin/python
		else
			ec yellow " python..."
			yum -yq --skip-broken install "$(yum -q provides python3 | grep -E '(x86_64|noarch)' | awk 'END {print $1}')" 2>&1 | stderrlogit 3
			! which python &> /dev/null && ln -s "$(which python3)" /usr/bin/python
		fi
	fi

	# misc
	pip_and_pyyaml
	mkdir -p /root/.parallel; touch /root/.parallel/will-cite

	# quit if critical items still arent installed
	for program in $requireds; do
		if ! rpm -q --quiet $program; then
			ec red "It looks like yum might not be working... try 'yum clean all && rpm --rebuilddb && yum update' before retrying this script! (I need the following yum packages: $requireds)"
			if [ "$(rpm --eval %rhel)" -le 7 ]; then
				ec red "You are on cent7, so ill let it slide because updated ipcalc isnt available. ipswaps to this server will potentially not work as a result, and you may find other weirdness!" | errorlogit 2 root
				sleep 2
			else
				exitcleanup 70
			fi
		fi
	done
}
