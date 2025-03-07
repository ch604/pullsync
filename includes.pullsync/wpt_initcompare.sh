wpt_initcompare(){ #only see how many items were better on target vs source and assign a winner, run after initial sync with initsyncwpt set.
	ec blue "Aggregating WPT results..."
	for each in $(cat $dir/marilldomains.txt | grep -vF '*'); do
		local dom=$(echo $each | cut -d: -f1)
		local ip=$(echo $each | cut -d: -f2)
		! grep -q ^$dom\  $dir/wptresults.txt && continue #skip if domain wasnt tested
		# read variables from source and target results files
		read -r loadtime_source ttfb_source source_a source_b source_c source_d source_e source_f <<<$(grep ^$dom\ Live\ DNS $dir/wptresults.txt | tail -1 | awk -F: '{print $2}')
		read -r loadtime_target ttfb_target target_a target_b target_c target_d target_e target_f <<<$(grep ^$dom\ $ip $dir/wptresults.txt | tail -1 | awk -F: '{print $2}')
		grep ^$dom\ Live\ DNS $dir/wptresults.txt | tail -1 | tee -a $dir/wptcompare.txt
		grep ^$dom\ $ip $dir/wptresults.txt | tail -1 | tee -a $dir/wptcompare.txt
		# set integer variables for wins and increment based on which grade is larger
		local source_wins=0
		local target_wins=0
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
		for each in a b c d e f; do
			if [[ "$(eval "echo \$$(echo source_${each})")" < "$(eval "echo \$$(echo target_${each})")" ]]; then
				((source_wins++))
			elif [[ "$(eval "echo \$$(echo source_${each})")" > "$(eval "echo \$$(echo target_${each})")" ]]; then
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
	done

	# total output
	ec green "Done! Links at: (cat $dir/wptresults.txt) and aggregate results at (cat $dir/wptcompare.txt)"
	if [ $(grep ^Source $dir/wptcompare.txt | wc -l) -gt $(grep ^Target $dir/wptcompare.txt | wc -l) ]; then
		ec red "Source server appears overall to have more wins than target! Check the results and see if you can increase speeds!"
	else
		ec green "Target server appears overall to have more wins than source! Grats~!"
	fi
	# if there were any non-As on target for certain values, make recommendations
	[ $turnonkeepalive ] && ec lightGreen "I recommend turning on Keep Alive to increase scores." | errorlogit 4
	[ $turnongzip ] && ec lightGreen "I recommend turning on gzip compression (mod_deflate) server-wide to increase scores." | errorlogit 4
	[ $turnoncache ] && ec lightGreen "I recommend turning on browser cache (mod_expires) server-wide to increase scores." | errorlogit 4
}
