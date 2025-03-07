wpt_speedtest(){ #actually perform the webpagespeed test. test domain $1 using live dns, or optionally against IP $2 (usage: wpt_speedtest domain.com [123.45.67.89])
	# specify server and location, and variables to use for the test
	local testserver="https://www.webpagetest.org"
	local loc="ec2-us-east-1-catchpoint"
	local wptargs="--data runs=3 --data noimages=1 --data ignoreSSL=1 --data location=$loc --data keep_test_private=1 --data video=0"

	# if there is an IP specified, use it, otherwise use live dns
	if [ "$2" ]; then
		ec yellow "Starting WPT against $1 using $2..."
		local testid=$(curl -kvs $testserver/runtest.php --data script=setDns+$1+$2%0D%0AsetDns+www.$1+$2%0D%0Anavigate+$1 $wptargs 2>&1 | grep ^\<\ Location\: | cut -d\= -f2 | sed 's/\r//')
	else
		ec yellow "Starting WPT against $1 using live DNS..."
		local testid=$(curl -kvs $testserver/runtest.php --data url=$1 $wptargs 2>&1 | grep ^\<\ Location\: | cut -d\= -f2 | sed 's/\r//')
	fi

	if [ $testid ]; then
		# if there is a test id, the test started
		local wptloop=1
		while [ $wptloop = 1 ]; do
			# check for completion every 2s
			sleep 2
			curl -ks $testserver/viewlog.php?test=$testid | grep -q Test\ Complete && wptloop=0
		done

		# record and aggregate results
		ec lightBlue "WPT for $1 using ${2:-Live DNS} complete: $testserver/results.php?test=$testid"
		local csvfile=$(mktemp)
		# bring down the csv file and pull out the necessary columns
		curl -ks $testserver/csv.php?test=$testid | tee $dir/wptresults/$1_${2:-LiveDNS}.csv | csvtool namedcol result,loadTime,TTFB,score_keep-alive,score_gzip,score_compress,score_progressive_jpeg,score_cache,score_cdn - | grep -v '^result,' > $csvfile
		# make an array to store the grades
		local -a lettergrades
		local medianttfb=$(awk -F, '{print $3}' $csvfile | sort | awkmedian)
		local medianlt=$(awk -F, '{print $2}' $csvfile | sort | awkmedian)
		# score the ttfb
		if (( $(echo "$medianttfb < 401" | bc -l) )); then lettergrades+=(A)
		elif (( $(echo "$medianttfb < 501" | bc -l) )); then lettergrades+=(B)
		elif (( $(echo "$medianttfb < 601" | bc -l) )); then lettergrades+=(C)
		elif (( $(echo "$medianttfb < 701" | bc -l) )); then lettergrades+=(D)
		else lettergrades+=(F)
		fi
		for col in 4 5 6 8 9; do
			# score the other columns
			local result=$(awk -F, '{print $'$col'}' $csvfile | sort | tail -1)
			if [ $result -eq -1 ]; then lettergrades+=(X)
			elif [ $result -le 59 ]; then lettergrades+=(F)
			elif [ $result -le 69 ]; then lettergrades+=(D)
			elif [ $result -le 79 ]; then lettergrades+=(C)
			elif [ $result -le 89 ]; then lettergrades+=(B)
			else lettergrades+=(A)
			fi
		done

		# output results
		ec lightBlue "Grades for $1 using ${2:-Live DNS}:\t Median load time: ${medianlt}ms\t Median TTFB: ${medianttfb}ms\t Letter grades: ${lettergrades[@]}"
		echo -e "$1 ${2:-Live DNS}: $testserver/results.php?test=$testid\n$1 ${2:-Live DNS}:\t $medianlt\t $medianttfb\t ${lettergrades[@]}\n" >> $dir/wptresults.txt
		# cleanup
		rm -f $csvfile
	else
		# test id failed to set, server wasnt listening or got a bad request
		ec red "WPT for $1 using ${2:-Live DNS} failed, unable to start test!"
		sleep .25 #give the process some time to start the sem --wait command just in case
	fi
}
