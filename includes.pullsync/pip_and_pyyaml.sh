pip_and_pyyaml() { #install pip and pyyaml for python decoding of yaml files
	if ! which pip &> /dev/null; then
		ec yellow " pip and pyyaml..."
		python -m ensurepip --upgrade 2>&1 | stderrlogit 3
	fi
	if which pip &> /dev/null; then
		pip install --upgrade pip pyyaml 2>&1 | stderrlogit 3
	else
		ec red "Install of pip python manager failed! Please install this manually and run \$(pip install pyyaml) before proceeding!"
		exitcleanup 140
	fi
}
