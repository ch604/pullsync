ab_test_localwrapper(){ #wrapper for ab_test, use specific target ip for apache bench request
	for each in $(cat $dir/marilldomains.txt | grep -vF '*'); do
		# use generated domain list with ips to create variables
		local dom=$(echo $each | cut -d: -f1)
		local ip=$(echo $each | cut -d: -f2)
		local eurl=$(get_effective_url $dom)
		if [[ $eurl =~ $dom ]]; then
			# run ab_test one at a time using sem with one job
			sem --bg --id ab_running --jobs 1 -u ec yellow "Running ${eurl} on ${ip}...";ab_test $(echo "$(echo $eurl | cut -d: -f1 | tr '[:upper:]' '[:lower:]')://$ip/$(echo $eurl | cut -d\/ -f4-)") 5 10 Host: $(echo $eurl | cut -d\/ -f3)
		else
			# if there is a different redirect url, dont test
			ec lightRed "$dom seems to redirect to a different effective url: $eurl! SAD! Not testing!"
		fi
	done
	# wait until all tests are done
	sem --wait --id ab_running
	ec green "Done! Info at: (cat $dir/abresults.txt)"
}
