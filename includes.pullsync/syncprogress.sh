 syncprogress() { #prints the sync status every few seconds over the same window, to show what is being synced at any given time. tails the individual log files for each package_account() to get the sync position, uses ps to determine which package functions are still running. prints the file open by the rsync process if log says it is mid rsync. $1 is pid of the parallel process, exits when parallel is done. accepts $2 optionally as the parallel function to watch for, otherwise it assumes packagefunction. the parallel function we are watching MUST have the cpanel username as the 2nd to last element (the last usually being a one-word stdout redirection, such as `>$dir/log.txt`).
	local function runningusers numprocs _ps _lsof current_disk restoredcount
	declare -a _files
	function="packagefunction"
	[ "$2" ] && function="$2"
	# experience infinity
	clear
	while kill -0 "$1" 2> /dev/null; do
		#read refresh delay file every loop, ensure sanity
		refreshdelay=$(cat "$dir/refreshdelay")
		[[ ! $refreshdelay =~ ^[0-9]+$ || $refreshdelay -gt 60 ]] && refreshdelay=3

		# get a list of running parallel processes, scraping the unique list of usernames
		# shellcheck disable=SC2009
		runningusers=$(ps ax | grep "$function" | grep -Ev '(parallel|grep)' | awk '{print $(NF-1)}' | sort -u)
		numprocs=$(wc -l <<< "$runningusers")
		# loop around the user list
		tput cup 0 0
		echo -e "---$c"
		if [ "$numprocs" -ne 0 ]; then
			_ps=$(ps ax 2> /dev/null)
			_lsof=$(lsof -c rsync -F n 2> /dev/null)
			for user in $runningusers; do
				processprogress "$user"
			done
		fi

		# print progress indicators for disk usage and total account count
		current_disk=0
		for each in $homemountpoints; do
			current_disk=$((current_disk + $(df "$each" | awk 'END {print $3}') ))
		done
		ecnl yellow "Disk progress (start/current/expected): $(human $((start_disk*1024)))/$(human $((current_disk*1024)))/$(human $((expected_disk*1024)))$c"
		progress_bar $((current_disk-start_disk)) $((expected_disk-start_disk))

		# tell tech which accts are done
		if [ "$function" == "packagefunction" ]; then
			# shellcheck disable=SC2046
			restoredcount=$(find /var/cpanel/users/ -maxdepth 1 -type f -printf "%f\n" | grep -cx $(while read -r each; do echo -ne "-e $each "; done < "$dir/userlist.txt"))
			ecnl yellow "Restored users: $restoredcount/$user_total$c"
			progress_bar "$restoredcount" "$user_total"
			echo -e "$c"
			if [ -s "$hostsfile" ] ; then
				# if anything was written to the hosts file, list the last few lines so spot testing can be done
				ecnl white "Last 3 hosts file lines:$c"
				ecnl yellow "$(tail -3 "$hostsfile" | head -1)$c"
				ecnl yellow "$(tail -2 "$hostsfile" | head -1)$c"
				ecnl yellow "$(tail -1 "$hostsfile")$c"
				echo -e "$c"
			else
				# otherwise skip a few lines
				echo -e "$c\n$c\n$c\n$c\n$c"
			fi
		else #all non-initial syncs
			ecnl green "Completed users: $(wc -w < "$dir/final_complete_users.txt")/$user_total$c"
			progress_bar "$(wc -w < "$dir/final_complete_users.txt")" "$user_total"
			# truncate a list of the completed users in case it gets too long, 10 lines total
			if [ "$(wc -c < "$dir/final_complete_users.txt")" -gt "$(($(tput cols) * 10))" ]; then
				echo -e "...$(paste -sd' ' "$dir/final_complete_users.txt" | rev | cut -c 1-$(($(tput cols) * 10 - 3)) | rev )$c"
			else
				echo -e "$(paste -sd' ' "$dir/final_complete_users.txt")$c"
			fi
		fi

		#error output
		if [ "$(wc -l < <(find "$dir"/log/*.error.log 2> /dev/null))" -gt 0 ]; then #one or more users have error logs with content
			ecnl lightRed "$wn Some users have sync errors:$c"
			echo -e "$(find "$dir"/log/*.error.log | awk -F/ '{print $NF}' | cut -d. -f1 | paste -sd' ')$c"
		else
			# otherwise skip a few lines
			echo -e "$c\n$c"
		fi
		if [ -f "$dir/did_not_restore.txt" ]; then # display mid-sync if there are restore errors
			ecnl lightRed "$xx Some users did not restore:$c"
			echo -e "$(paste -sd' ' "$dir/did_not_restore.txt")$c"
		else
			# otherwise skip a few lines
			echo -e "$c\n$c"
		fi

		# clear to the bottom
		for i in $(seq $(( 19 + (numprocs * 5) )) "$(tput lines)"); do
			echo -e "$c"
		done
		# check for stuck transfers
		if [ "$function" == "packagefunction" ] && [ -n "$recheckpid" ]; then
			# there was a potentially stuck session found from the 'else' statement. check for it now
			# shellcheck disable=SC2009
			if [ "$recheckpid" = "$(ps cx | grep view_transfer 2>/dev/null | awk '{print $1}')" ]; then
				# if the active view_transfer matches the one from the last check, increment count
				(( recheck += 1 ))
				if [ "$recheck" -eq 9 ]; then
					# restore has been stuck for 30 seconds with finished child, kill the parent
					ec red "Killing stuck transfer_session ${active_restorepkg}..."
					echo "killed $active_restorepkg pid $recheckpid: $(ps ax | grep view_transfer 2>/dev/null | grep -v grep)" | errorlogit 2 root
					kill "$recheckpid" 2>&1 | stderrlogit 2
					unset recheckpid recheck active_restorepkg # unset variables to escape this loop next time
				fi
			else
				unset recheckpid recheck active_restorepkg #we have a new view_transfer pid
			fi
		elif [ "$function" == "packagefunction" ]; then
			echo -e "$c" # clear text from last kill if any
			# get the session id of the restorepkg in progress
			# shellcheck disable=SC2009
			active_restorepkg=$(ps ax | grep view_transfer 2>/dev/null | grep -v grep | awk '{print $NF}' | head -1)
			mapfile -t _files <<< /var/cpanel/transfer_sessions/"$active_restorepkg"/item-RESTORE*
			if [ -n "$active_restorepkg" ] && [ -f "${_files[0]}" ]; then
				# active restore session with child process done, might be stuck. get the pid number to recheck.
				# shellcheck disable=SC2009
				recheckpid=$(ps cx | grep view_transfer 2>/dev/null | awk '{print $1}' | head -1)
				[ -z "$recheckpid" ] && unset recheckpid recheck active_restorepkg # view_transfer ended cleanly before we could get to it
			else
				unset recheckpid recheck active_restorepkg # no active restore session
			fi
		fi
		# wait for more stuff to happen
		sleep "$refreshdelay"
	done
	clear
}
