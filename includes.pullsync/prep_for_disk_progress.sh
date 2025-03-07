prep_for_disk_progress() { #run before syncprogress() is called to prepare for progress bars
	start_disk=0
	homemountpoints=$(for each in $localhomedir; do findmnt -nT "$each" | awk '{print $1}'; done | sort -u)
	for each in $homemountpoints; do
		start_disk=$((start_disk + $(df "$each" | awk 'END {print $3}')))
	done
	case $synctype in
		single|list|domainlist|all|skeletons)
			if [ "$iusedrepquota" ]; then
				#TODO this includes mysql disk usage from space_check()
				expected_disk=$((start_disk + remote_used_space))
			else
				#TODO this isnt completely accurate either as it includes all users and linux files
				expected_disk=$remote_used_space
			fi
			;;
		*)
			expected_disk=$((start_disk + finaldiff))
			;;
	esac
}
