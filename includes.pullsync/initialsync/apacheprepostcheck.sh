apacheprepostcheck() { #imports custom includes
	#list of files to check for differences
	apachefilelist="post_virtualhost_2.conf post_virtualhost_global.conf pre_main_2.conf pre_main_global.conf pre_virtualhost_2.conf pre_virtualhost_global.conf"
	for file in $apachefilelist; do
		if [ -s $dir/usr/local/apache/conf/includes/$file ] && [ "$(diff -q $dir/usr/local/apache/conf/includes/$file /usr/local/apache/conf/includes/$file)" ]; then
			#remote file has size and is different to local file
			ec lightGreen "Difference detected in $file (lines with < are missing in local file)"
			#print difference
			diff $dir/usr/local/apache/conf/includes/$file /usr/local/apache/conf/includes/$file
			if yesNo "Replace $file on local server?"; then
				#backup original and copy remote file
				mv /usr/local/apache/conf/includes/$file{,.pullsync}
				cp -a $dir/usr/local/apache/conf/includes/$file /usr/local/apache/conf/includes/
				#test new config
				httpd -t 2>&1 | stderrlogit 4
				if [ "${PIPESTATUS[0]}" = "0" ]; then
					#config syntax ok, restart httpd
					/scripts/restartsrv_httpd 2>&1 | stderrlogit 4
					ec green "Success!"
					includeschanges=1
				else
					#revert
					ec red "Failure detected during config test of httpd, reverting $file change" | errorlogit 2
					rm /usr/local/apache/conf/includes/$file
					mv /usr/local/apache/conf/includes/$file{.pullsync,}
				fi
			fi
		fi
	done
}
