wpt_localwrapper(){ #do webpagetest on all domains. list from from marilldomains.txt
	echo -e "Letter grades are: First Byte Time, Keep-alive, Server Gzip, Image Compression, Browser Cache, CDN use.\nLine format is Median Load Time, Median TTFB, Letter Grades." | tee -a $dir/wptresults.txt
	for each in $(cat $dir/marilldomains.txt | grep -vF '*'); do
		# run wpt_speedtest on specified ip , with $jobnum runs in parallel
		local dom=$(echo $each | cut -d: -f1)
		local ip=$(echo $each | cut -d: -f2)
		sem --bg --id wpt_running --jobs $jobnum -u wpt_speedtest $dom $ip
	done
	# wait for all tests to finish
	sem --wait --id wpt_running

	# print results
	ec blue "Aggregating results..."
	for each in $(cat $dir/marilldomains.txt | grep -vF '*'); do
		local dom=$(echo $each | cut -d: -f1)
		local ip=$(echo $each | cut -d: -f2)
		# read variables from the results file
		read -r loadtime_target ttfb_target target_a target_b target_c target_d target_e target_f <<<$(grep ^$dom\ $ip $dir/wptresults.txt | tail -1 | awk -F: '{print $2}')
		# if there were any non-As for certain items, ping tech
		[[ "$target_b" != "A" ]] && turnonkeepalive=1
		[[ "$target_c" != "A" ]] && turnongzip=1
		[[ "$target_e" != "A" ]] && turnoncache=1
	done
	ec green "Done! Links at: (cat $dir/wptresults.txt)"

	# if there were any non-As on target for certain values, let tech fix
	if [ $turnonkeepalive ]; then
		ec lightGreen "I recommend turning on Keep Alive to increase scores."
		if yesNo "Would you like to turn on keepalive now?"; then
			basic_optimize_keepalive
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		fi
	fi
	if [ $turnongzip ]; then
		ec lightGreen "I recommend turning on gzip compression (mod_deflate) server-wide to increase scores."
		if yesNo "Would you like to turn on mod_deflate globally now?"; then
			basic_optimize_deflate
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		fi
	fi
	if [ $turnoncache ]; then
		ec lightGreen "I recommend turning on browser cache (mod_expires) server-wide to increase scores."
		if yesNo "Would you like to turn on mod_expires globally now?"; then
			basic_optimize_expires
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		fi
	fi
}
