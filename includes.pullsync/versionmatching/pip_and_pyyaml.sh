pip_and_pyyaml() { #install pip and pyyaml for python decoding of yaml files
	if [ ! "$(which pip 2> /dev/null)" ]; then
		ec yellow " pip and pyyaml..."
		curl -s "https://bootstrap.pypa.io/2.6/get-pip.py" -o "/root/get-pip.py"
		python /root/get-pip.py 2>&1 | stderrlogit 3
	fi
	if [ "$(which pip 2> /dev/null)" ]; then
		pip install --upgrade pip pyyaml 2>&1 | stderrlogit 3
	else
		ec red "Install of pip python manager failed! Please install this manually and run \`pip install pyyaml\` before proceeding!"
		exitcleanup 140
	fi
}
