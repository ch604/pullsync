wpt_remotewrapper() { #do webpagetest for all domains in $domainlist against live dns
	echo -e "Letter grades are: First Byte Time, Keep-alive, Server Gzip, Image Compression, Browser Cache, CDN use.\nLine format is Median Load Time, Median TTFB, Letter Grades." | tee -a $dir/wptresults.txt
	for dom in $domainlist; do
		# run vanilla speedtest at live dns
		sem --bg --id wpt_running --jobs $jobnum -u wpt_speedtest $dom
	done
	# wait for all test to finish
	sem --wait --id wpt_running
	ec green "Done! Links at: (cat $dir/wptresults.txt)"
}
