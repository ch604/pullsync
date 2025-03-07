parallel_cllve() { #matches source lve settings for user passed as $1. adjusts if ncpu is not set.
	local lveline
	lveline=$(sssh "lvectl list-user" | column -t | grep "^$1 ")
	if [ "$lveline" ]; then
		ec yellow "  setting $1"
		if [ "$(echo "$lveline" | wc -w)" -eq "9" ]; then
			lvectl set-user "$1" --speed="$(echo "$lveline" | awk '{print $2}')"% --ncpu="$(echo "$lveline" | awk '{print $3}')" --pmem="$(echo "$lveline" | awk '{print $4}')" --vmem="$(echo "$lveline" | awk '{print $5}')" --maxEntryProcs="$(echo "$lveline" | awk '{print $6}')" --nproc="$(echo "$lveline" | awk '{print $7}')" --io="$(echo "$lveline" | awk '{print $8}')" --iops="$(echo "$lveline" | awk '{print $9}')"
		else
			lvectl set-user "$1" --speed="$(echo "$lveline" | awk '{print $2}')"% --ncpu=1 --pmem="$(echo "$lveline" | awk '{print $3}')" --vmem="$(echo "$lveline" | awk '{print $4}')" --maxEntryProcs="$(echo "$lveline" | awk '{print $5}')" --nproc="$(echo "$lveline" | awk '{print $6}')" --io="$(echo "$lveline" | awk '{print $7}')" --iops="$(echo "$lveline" | awk '{print $8}')"
		fi
	fi
}
