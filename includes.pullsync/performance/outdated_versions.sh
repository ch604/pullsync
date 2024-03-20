outdated_versions() {
	ec yellow "Updating versionfinder db..."
	versionfinder --update &> /dev/null
	sleep 1
	versionfinder --update &> /dev/null
	ec yellow "Finding old CMS versions..."
	versionfinder --outdated --user $userlist 2> /dev/null | grep -v -e ^$ -e versionfinder\.pl -e \.vf_signatures -e updated, -e ^update$ -e ^Version\ Finder -e ^Checking\ for\  -e ^==== > $dir/outdatedversions.txt
	if [ -s $dir/outdatedversions.txt ]; then
		ec lightRed "$(cat $dir/outdatedversions.txt | wc -l) outdated installs found!"
		cat $dir/outdatedversions.txt | awk '{print $3}'
		ec lightRed "See outdatedversions.txt for details (cat $dir/outdatedversions.txt)"
	fi
}
