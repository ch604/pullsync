copy_cloudlinux_configs() { #adjust php and lve settings on target to match source cloudlinux settings
	ec yellow "Copying CloudLinux configurations..."
	#doesnt work if no one is in the cage! add everyone
	cagefsctl --enable-all
	cagefsctl --force-update
	if [ $(which selectorctl 2> /dev/null) ] && [ $(sssh "which selectorctl 2> /dev/null") ]; then
		#altphp present on both servers
		ec yellow " altphp..."
		#detect disabled versions on source
		for ver in $(sssh "selectorctl --summary" | awk '$2 == "-" {print $1}'); do
			ec yellow "  disabling altphp ${ver}"
			selectorctl -N ${ver}
		done
		#set global default version
		local phpdefver=$(sssh "selectorctl --summary" | awk '$3 == "d" {print $1}')
		ec yellow "  setting default version to ${phpdefver}"
		selectorctl -B ${phpdefver}
		#print, organize, and set php extension lists for all enabled versions
		for ver in $(selectorctl --summary | awk '$2 == "e" {print $1}' | grep -v ^native); do
			local versionset=$(sssh "selectorctl -G -v $ver" | awk '$1 == "+" {print $2}' | tr '\n' ',' | sed -e 's/,$/\n/')
			ec yellow "  setting extensions for $ver"
			selectorctl -R $versionset -v $ver
		done
		#list php versions available through ea4 by number only
		local available_ea4=$(/usr/local/cpanel/bin/rebuild_phpconf --available | tr -dc '0-9\n')
	fi
	if [ $(which lvectl 2> /dev/null) ] && [ $(sssh "which lvectl 2> /dev/null") ]; then
		#lvectl available on both servers
		ec yellow " lve..."
		#detect default lve settings and adjust target
		local defaultline=$(sssh "lvectl list | column -t | grep ^default\ ")
		if [ "$defaultline" ]; then
			ec yellow "  setting defaults"
			if [ "$(echo $defaultline | wc -w)" -eq "9" ]; then
				lvectl set default --speed=$(echo $defaultline | awk '{print $2}')% --ncpu=$(echo $defaultline | awk '{print $3}') --pmem=$(echo $defaultline | awk '{print $4}') --vmem=$(echo $defaultline | awk '{print $5}') --maxEntryProcs=$(echo $defaultline | awk '{print $6}') --nproc=$(echo $defaultline | awk '{print $7}') --io=$(echo $defaultline | awk '{print $8}') --iops=$(echo $defaultline | awk '{print $9}')
			else
				lvectl set default --speed=$(echo $defaultline | awk '{print $2}')% --ncpu=1 --pmem=$(echo $defaultline | awk '{print $3}') --vmem=$(echo $defaultline | awk '{print $4}') --maxEntryProcs=$(echo $defaultline | awk '{print $5}') --nproc=$(echo $defaultline | awk '{print $6}') --io=$(echo $defaultline | awk '{print $7}') --iops=$(echo $defaultline | awk '{print $8}')
			fi
		fi
		#adjust users' lve settings
		for user in $userlist; do
			local lveline=$(sssh "lvectl list-user | column -t | grep ^${user}\ ")
			if [ "$lveline" ]; then
				ec yellow "  setting $user"
				if [ "$(echo $lveline | wc -w)" -eq "9" ]; then
					lvectl set-user $user --speed=$(echo $lveline | awk '{print $2}')% --ncpu=$(echo $lveline | awk '{print $3}') --pmem=$(echo $lveline | awk '{print $4}') --vmem=$(echo $lveline | awk '{print $5}') --maxEntryProcs=$(echo $lveline | awk '{print $6}') --nproc=$(echo $lveline | awk '{print $7}') --io=$(echo $lveline | awk '{print $8}') --iops=$(echo $lveline | awk '{print $9}')
				else
					lvectl set-user $user --speed=$(echo $lveline | awk '{print $2}')% --ncpu=1 --pmem=$(echo $lveline | awk '{print $3}') --vmem=$(echo $lveline | awk '{print $4}') --maxEntryProcs=$(echo $lveline | awk '{print $5}') --nproc=$(echo $lveline | awk '{print $6}') --io=$(echo $lveline | awk '{print $7}') --iops=$(echo $lveline | awk '{print $8}')
				fi
			fi
		done
		#apply changes
		lvectl apply all
	fi
	ec yellow " php selector..."
	for user in $userlist; do
		if [ -d $(eval echo ~$user)/.cl.selector ]; then
			#restore php selector options from migrated files
			ec yellow "  setting $user"
			prefix=$(cagefsctl --getprefix $user)
			mkdir -p $dir/oldcagefs/$prefix/$user
			mv /var/cagefs/$prefix/$user/etc/cl.selector $dir/oldcagefs/$prefix/$user/
			mv /var/cagefs/$prefix/$user/etc/cl.php.d $dir/oldcagefs/$prefix/$user/
			cagefsctl --force-update-etc $user
		fi
	done
}
