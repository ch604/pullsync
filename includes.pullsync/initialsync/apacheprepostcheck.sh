apacheprepostcheck() { #imports custom includes
	#list of files to check for differences
	apachefilelist="post_virtualhost_2.conf post_virtualhost_global.conf pre_main_2.conf pre_main_global.conf pre_virtualhost_2.conf pre_virtualhost_global.conf"
	for file in $apachefilelist; do
            #backup original and copy remote file
			mv /usr/local/apache/conf/includes/$file{,.pullsync}
			cp -a $dir/usr/local/apache/conf/includes/$file /usr/local/apache/conf/includes/
			#test new config
			httpd -t 2>&1 | stderrlogit 4
	done
}
