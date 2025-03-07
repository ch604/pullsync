ab_test_remotewrapper(){ #wrapper for ab_test, use public dns for apache bench request
	for dom in $domainlist; do
		# get the effective url in case of redirect
		local eurl=$(get_effective_url $dom)
		if [[ $eurl =~ $dom ]]; then
			# run ab_test one at a time using sem with 1 job
			sem --bg --id ab_running --jobs 1 -u ec yellow "Running ${eurl} on public DNS...";ab_test ${eurl} 5 10
		else
			# dont test if there is a redirect
			ec lightRed "$dom seems to redirect to a different effective url: ${eurl}! SAD! Not testing!"
		fi
	done
	# wait until all tests are done
	sem --wait --id ab_running
	ec green "Done! Info at: (cat $dir/abresults.txt)"
}
