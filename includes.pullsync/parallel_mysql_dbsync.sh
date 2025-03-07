parallel_mysql_dbsync() { #sync database and table passed as $1 and $2 respectively.
	local db tb
	declare -a dumpstatus
	db=$1
	tb=$2
	# perform the dump in a subshell to collect the pipestatus, getting exit code for the dump and the import at the same time
	if [ "$nodbscan" ]; then
		# shellcheck disable=SC2086
		IFS=" " read -ra dumpstatus < <(sssh_sql dump $mysqldumpopts "$db" "$tb" 2>> "$dir/log/dbsync.log" | sed '1{/999999.*sandbox/d}' | sql "$db" 2>> "$dir/log/dbsync.log"; printf %s "${PIPESTATUS[*]}")
	else
		# shellcheck disable=SC2086
		IFS=" " read -ra dumpstatus < <(sssh_sql dump $mysqldumpopts "$db" "$tb" 2>> "$dir/log/dbsync.log" | sed '1{/999999.*sandbox/d}' | tee -p >(dbscan) | sql "$db" 2>> "$dir/log/dbsync.log"; printf %s "${PIPESTATUS[*]}")
	fi

	# parse the status to see if anything failed
	if [ "${dumpstatus[0]}" -ne 0 ]; then
		# dump failed, retry without dbscan
		echo "[INFO] Dump of $db.$tb returned non-zero exit code (${dumpstatus[*]}), retrying..." >> "$dir/error.log"
		# shellcheck disable=SC2086
		IFS=" " read -ra dumpstatus < <(sssh_sql dump $mysqldumpopts "$db" "$tb" 2>> "$dir/log/dbsync.log" | sed '1{/999999.*sandbox/d}' | sql "$db" 2>> "$dir/log/dbsync.log"; printf %s "${PIPESTATUS[*]}")
		if [ "${dumpstatus[0]}" -ne 0 ]; then
			# second dump failed too, mark as failed
			echo "[ERROR] Dump of $db.$tb returned non-zero exit code (${dumpstatus[*]}), marking as failed" >> "$dir/error.log"
			echo "$db.$tb" >> "$dir/dbdump_fails.txt"
		else
			echo "[INFO] Dump of $db.$tb succeeded on second attempt" >> "$dir/error.log"
		fi
	fi
	if [ "${dumpstatus[0]}" -eq 0 ] && [ "${dumpstatus[$((${#dumpstatus[@]} - 1))]}" -ne 0 ]; then
		# dump succeeded but import failed, mark as failed
		echo "[ERROR] Dump of $db.$tb succeeded, but import returned non-zero exit code (${dumpstatus[*]}), marking as failed" >> "$dir/error.log"
		echo "$db.$tb" >> "$dir/dbdump_fails.txt"
	fi
}
