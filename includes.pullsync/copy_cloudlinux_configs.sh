copy_cloudlinux_configs() { #adjust php and lve settings on target to match source cloudlinux settings
	local phpdefver versionset available_ea4 defaultline
	ec yellow "Copying CloudLinux configurations..."
	#doesnt work if no one is in the cage! add everyone
	cagefsctl --enable-all
	cagefsctl --force-update
	if which selectorctl &> /dev/null && sssh "which selectorctl" &> /dev/null; then
		#altphp present on both servers
		ec yellow " altphp..."
		#detect disabled versions on source
		for ver in $(sssh "selectorctl --summary" | awk '$2 == "-" {print $1}'); do
			ec yellow "  disabling altphp ${ver}"
			selectorctl -N "$ver"
		done
		#set global default version
		phpdefver=$(sssh "selectorctl --summary" | awk '$3 == "d" {print $1}')
		ec yellow "  setting default version to ${phpdefver}"
		selectorctl -B "$phpdefver"
		#print, organize, and set php extension lists for all enabled versions
		for ver in $(selectorctl --summary | awk '$2 == "e" {print $1}' | grep -v ^native); do
			versionset=$(sssh "selectorctl -G -v $ver" | awk '$1 == "+" {print $2}' | tr '\n' ',' | sed -e 's/,$/\n/')
			ec yellow "  setting extensions for $ver"
			selectorctl -R "$versionset" -v "$ver"
		done
		#list php versions available through ea4 by number only
		available_ea4=$(/usr/local/cpanel/bin/rebuild_phpconf --available | tr -dc '0-9\n')
	fi
	if which lvectl &> /dev/null && sssh "which lvectl" &> /dev/null; then
		#lvectl available on both servers
		ec yellow " lve..."
		#detect default lve settings and adjust target
		defaultline=$(sssh "lvectl list | column -t | grep ^default\ ")
		if [ "$defaultline" ]; then
			ec yellow "  setting defaults"
			if [ "$(wc -w <<< "$defaultline")" -eq "9" ]; then
				lvectl set default --speed="$(awk '{print $2}' <<< "$defaultline")"% --ncpu="$(awk '{print $3}' <<< "$defaultline")" --pmem="$(awk '{print $4}' <<< "$defaultline")" --vmem="$(awk '{print $5}' <<< "$defaultline")" --maxEntryProcs="$(awk '{print $6}' <<< "$defaultline")" --nproc="$(awk '{print $7}' <<< "$defaultline")" --io="$(awk '{print $8}' <<< "$defaultline")" --iops="$(awk '{print $9}' <<< "$defaultline")"
			else
				lvectl set default --speed="$(awk '{print $2}' <<< "$defaultline")"% --ncpu=1 --pmem="$(awk '{print $3}' <<< "$defaultline")" --vmem="$(awk '{print $4}' <<< "$defaultline")" --maxEntryProcs="$(awk '{print $5}' <<< "$defaultline")" --nproc="$(awk '{print $6}' <<< "$defaultline")" --io="$(awk '{print $7}' <<< "$defaultline")" --iops="$(awk '{print $8}' <<< "$defaultline")"
			fi
		fi
		#adjust users' lve settings
		# shellcheck disable=SC2086
		parallel -j 100% -u 'parallel_cllve.sh {}' ::: $userlist
		#apply changes
		lvectl apply all
	fi

	ec yellow " php selector..."
	# shellcheck disable=SC2086
	parallel -j 100% -u 'parallel_clphp {}' ::: $userlist
}
