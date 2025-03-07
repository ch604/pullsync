marill_gen() { #do marill testing and notify of any failures
	local fails percentfail
	ec yellow "Generating output for marill auto-testing..."

	# run marill against the list of domains to test
	/root/bin/marill --allow-insecure --no-banner -a --ignore-remote --delay=1s --debug-log "$dir/marill_log.txt" --result-file "$dir/marill_output.txt" --domains "$(grep -vF '*' "$dir/marilldomains.txt")" 2>&1 | stderrlogit 3
	if [ "${PIPESTATUS[0]}" != 0 ]; then
		ec red "Marill returned non-zero exit code! There was probably an issue generating the marilldomains.txt file, indicating an issue with something in /var/cpanel/users. Check this out manually!"
		return
	else
		ec green "Success! See $dir/marill_output.txt"
	fi

	# exclude those domains that do not resolve anywhere from the failure list
	if [ -s "$dir/no_resolve.txt" ]; then
		fails=$(grep "^\[FAILURE" "$dir/marill_output.txt" | grep -vf "$dir/no_resolve.txt")
	else
		fails=$(grep "^\[FAILURE" "$dir/marill_output.txt")
	fi

	# if there were failures, get the ratio of wins to losses
	if [ "$fails" ]; then
		percentfail=$(( 100 * $(wc -l <<< "$fails") / $(wc -l < "$dir/marill_output.txt" 2> /dev/null || echo 0) ))
		# shellcheck disable=SC2001
		echo "$fails" | sed 's/\[FAILURE\]/\n[FAILURE]/g' >> "$dir/marill_fails.txt"
		ec lightRed "Some domains returned a FAILURE code from marill, $percentfail% of the tested domains which resolved. Please check these manually! (cat $dir/marill_fails.txt)"
	fi
}
