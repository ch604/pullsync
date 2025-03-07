download_marill() { #download the marill program
	ec yellow "Installing marill from liam.sh..."
	yum -yq localinstall https://liam.sh/ghr/marill_0.1.1_linux_amd64.rpm 2>&1 | stderrlogit 4
	! which marill &> /dev/null && ec red "Could not fetch marill, skipping auto-testing." && unset runmarill
}
