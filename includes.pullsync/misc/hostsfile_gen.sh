hostsfile_gen() { #compiles a list of hosts file entries generated from hosts_file(), generates a testing reply to customer, and uploads both via haste(). run as part of initial sync, and as own function. requires userlist, domainlist, cpanel_main_ip
	#hostscheck
	if [ "$userlist" ]; then
		ec yellow "Adding HostsCheck.php to migrated users..."
		cp -a /root/includes.pullsync/text_files/hostsCheck.txt $dir/HostsCheck.php
		for user in $userlist; do
			local userhome_local=`grep ^$user: /etc/passwd | tail -n1 |cut -d: -f6`
			docroots=`grep DocumentRoot /usr/local/apache/conf/httpd.conf |grep $userhome_local| awk '{print $2}'`
			for docroot in $docroots; do
				cp -a $dir/HostsCheck.php $docroot/
				chown $user. $docroot/HostsCheck.php
				chmod 644 $docroot/HostsCheck.php
			done
		done
#		ec yellow "Ensuring short_open_tag..."
#		for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do
#			[ -f /opt/cpanel/$each/root/etc/php.d/local.ini ] && file=/opt/cpanel/$each/root/etc/php.d/local.ini || file=/opt/cpanel/$each/root/etc/php.ini
#			sed -i "s/^\(short_open_tag\ =\ \).*$/\1On/" $file
#			unset file
#		done
	else
		ec red "Warning: Userlist variable not detected when creating test file!"
	fi

	#test urls
	> /usr/local/apache/htdocs/migration_test_urls.html #blank original tests file
	if [ "$domainlist" ]; then
		ec yellow "Generating migration test urls..."
		for domain in $domainlist; do
			echo "http://$domain/HostsCheck.php" >> /usr/local/apache/htdocs/migration_test_urls.html
		done
		test_urls=`cat /usr/local/apache/htdocs/migration_test_urls.html |haste`
		#save hastbin url in $dir
		echo $test_urls > $dir/test_urls
	else
		ec red "Warning: Could not genearte test urls, no domainlist."
	fi

	#upload hostsfile_alt to hastebin:
	hostsfile_url=`cat $hostsfile_alt | haste`
	echo $hostsfile_url > $dir/hostsfile_url

	#generate reply
	ec yellow "Generating response to customer..."
	cp -a /root/includes.pullsync/text_files/pullsync_reply.txt $dir/pullsync_reply.txt

	#edit reply
	sed -i -e "s|http://\${ip}/hostsfile.txt|$hostsfile_url|" $dir/pullsync_reply.txt
	sed -i -e "s|http://\${ip}/migration_test_urls.html|$test_urls|" $dir/pullsync_reply.txt
	#remove final sync message
	if [ $remove_final_sync_message ]; then
		sed -i -e "s/\ If\ DNS\ is\ updated\ prematurely,\ a\ final\ sync\ of\ data\ may\ not\ be\ possible.$//" -e "/^Since\ it\ is/,+1d" -e "/^Once\ testing\ is/c\Once testing is complete, DNS for the migrated domains can be updated to make the new server live at your convenience. This is done at the current nameservers for each domain; let us know if you need help determining where your nameservers are. If you are planning to change nameservers, please let us know, and we can provide additional details on switching to Liquid Web\'s nameservers, or setting up your own custom nameservers. Please also know that we will not automatically terminate the old hosting solution for you; this must be requested separately once you are sure you no longer need the old server." $dir/pullsync_reply.txt
	fi


	#send to paste server
	reply_url=`cat $dir/pullsync_reply.txt | haste`
	echo $reply_url > $dir/reply_url
	ec green "Reply generated at $reply_url"
}
