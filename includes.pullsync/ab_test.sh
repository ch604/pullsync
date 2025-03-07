ab_test(){ #test domain $1 with $2 concurrent requests for $3 seconds (usage: ab_test domain.com 5 10). all remaining arguments are passed to -H.
	# store some variables
	local file=$(mktemp)
	local dom=$1
	shift
	local reqs=$1
	shift
	local secs=$1
	shift

	# run ab
	ab -q -c $reqs -t $secs -H "${*}" $dom/ 2>&1 >$file

	# fill variable with data from the output file
	local rps=$(grep ^Requests\ per\ second\: $file | awk '{print $4}')
	local response_time=$(grep ^\ \ 95% $file | awk '{print $2}')
	#number of failed requests, less the number of length errors (which indicate session variable usually)
	local length_errors=$(grep Exceptions\: $file | tr -d , | awk '{print $6}')
	local failed_reqs=$(( $(grep ^Failed\ requests\: $file | awk '{print $3}') - ${length_errors:-0} ))

	# print output and log
	ec lightBlue "Test complete! RPS: $rps, 95%: ${response_time}ms, Err: $failed_reqs"
	echo -e "\n\$(ab -c $reqs -t $secs -H \""${*}"\" $dom)\nRequests per second: $rps\nErrors: $failed_reqs\n95% response time: ${response_time}ms" >> $dir/abresults.txt
	rm -f $file
}
