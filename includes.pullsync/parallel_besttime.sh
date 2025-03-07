parallel_besttime() { # wrapper for sqlite3 transaction to run in parallel to get the best time for a final sync based on traffic stats
	sssh "[ -f /var/cpanel/bandwidth/$1.sqlite ] && sqlite3 /var/cpanel/bandwidth/$1.sqlite \"select bytes,time(unixtime, 'unixepoch', 'localtime') from bandwidth_hourly where protocol = 'http';\""
}
