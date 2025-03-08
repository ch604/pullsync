wpt_compare() { #do webpagetest for domains in marilldomains.txt twice, once for the listed ip and once for live dns, and compare results live to target. skip sites live on target.
	local dom ip liveip source_wins target_wins
	# put some notes into the results to make them readable
	echo -e "Letter grades are: First Byte Time, Keep-alive, Server Gzip, Image Compression, Browser Cache, CDN use.\nLine format is Median Load Time, Median TTFB, Letter Grades." | tee -a $dir/wptresults.txt
	ec yellow "Comparing performance of target domains to source..."
	while read -r each; do
		# for every domain, run wpt_speedtest twice, doing $jobnum runs in parallel
		dom=$(cut -d: -f1 <<< $each)
		ip=$(cut -d: -f2 <<< $each)
		liveip=$(dig +short $dom | tail -1)
		if [ "$liveip" == "$ip" ]; then
			ec lightRed "$dom is already live on target! Not running compare for this domain."
		else
			sem --bg --id wpt_running --jobs $jobnum -u wpt_speedtest $dom
			sem --bg --id wpt_running --jobs $jobnum -u wpt_speedtest $dom $ip
		fi
	done < <(grep -vF '*' "$dir/marilldomains.txt")
	# wait for all tests to finish
	sem --wait --id wpt_running

	#see how many items were better on target vs source and assign a winner
	ec blue "Aggregating results..."
	while read -r each; do
		# run these one at a time so that the output is in order
		dom=$(echo $each | cut -d: -f1)
		ip=$(echo $each | cut -d: -f2)
		! grep -q ^$dom\  $dir/wptresults.txt && continue #skip to next item in for loop if domain wasnt tested
		# read variables from source and target results files
		read -r loadtime_source ttfb_source source_a source_b source_c source_d source_e source_f < <(grep ^$dom\ Live\ DNS $dir/wptresults.txt | tail -1 | awk -F: '{print $2}')
		read -r loadtime_target ttfb_target target_a target_b target_c target_d target_e target_f < <(grep ^$dom\ $ip $dir/wptresults.txt | tail -1 | awk -F: '{print $2}')
		grep ^$dom\ Live\ DNS $dir/wptresults.txt | tail -1 | tee -a $dir/wptcompare.txt
		grep ^$dom\ $ip $dir/wptresults.txt | tail -1 | tee -a $dir/wptcompare.txt
		# set integer variables for wins and increment based on which grade is larger
		source_wins=0
		target_wins=0
		# nobody wins in case of tie
		if [ $loadtime_source -lt $loadtime_target ]; then
			((source_wins++))
		elif [ $loadtime_source -gt $loadtime_target ]; then
			((target_wins++))
		fi
		if [ $ttfb_source -lt $ttfb_target ]; then
			((source_wins++))
		elif [ $ttfb_source -gt $ttfb_target ]; then
			((target_wins++))
		fi
		for score in a b c d e f; do
			if [[ "$(eval "echo \$source_$score")" < "$(eval "echo \$target_$score")" ]]; then
				((source_wins++))
			elif [[ "$(eval "echo \$source_$score")" > "$(eval "echo \$target_$score")" ]]; then
				((target_wins++))
			fi
		done
		# if we got less than straight As on target for certain values, notify tech to make some config changes
		[[ "$target_b" != "A" ]] && turnonkeepalive=1
		[[ "$target_c" != "A" ]] && turnongzip=1
		[[ "$target_e" != "A" ]] && turnoncache=1
		# display results
		if [ $source_wins -gt $target_wins ]; then
			ec red "Source server had more wins than target..."
			echo "Source is superior $source_wins to $target_wins" >> $dir/wptcompare.txt
		else
			ec green "Target server had equal or more wins than source!"
			echo "Target is superior $target_wins to $source_wins" >> $dir/wptcompare.txt
		fi
	done < <(grep -vF '*' "$dir/marilldomains.txt")

	# total output
	ec green "Done! Links at: (cat $dir/wptresults.txt) and aggregate results at (cat $dir/wptcompare.txt)"
	if [ "$(grep -c ^Source $dir/wptcompare.txt)" -gt "$(grep -c ^Target $dir/wptcompare.txt)" ]; then
		ec red "Source server appears overall to have more wins than target! Check the results and see if you can increase speeds!"
	else
		ec green "Target server appears overall to have more wins than source! Grats~!"
	fi

	# if there were any non-As on target for certain values, let tech fix
	if [ "$turnonkeepalive" ]; then
		ec lightGreen "I recommend turning on Keep Alive to increase scores."
		if yesNo "Would you like to turn on keepalive now?"; then
			basic_optimize_keepalive
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		fi
	fi
	if [ "$turnongzip" ]; then
		ec lightGreen "I recommend turning on gzip compression (mod_deflate) server-wide to increase scores."
		if yesNo "Would you like to turn on mod_deflate globally now?"; then
			basic_optimize_deflate
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		fi
	fi
	if [ "$turnoncache" ]; then
		ec lightGreen "I recommend turning on browser cache (mod_expires) server-wide to increase scores."
		if yesNo "Would you like to turn on mod_expires globally now?"; then
			basic_optimize_expires
			/scripts/restartsrv_apache 2>&1 | stderrlogit 3
		fi
	fi
}
