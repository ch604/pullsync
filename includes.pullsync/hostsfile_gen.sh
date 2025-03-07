hostsfile_gen() { #compiles a list of hosts file entries generated from hosts_file(), generates a testing reply to customer, and uploads both via haste(). run as part of initial sync, and as own function. requires userlist, domainlist, cpanel_main_ip
	#hostscheck
	if [ "$userlist" ]; then
		ec yellow "Adding HostsCheck.php to migrated users..."
		cp -a /root/includes.pullsync/text_files/hostsCheck.txt $dir/HostsCheck.php
		parallel -j 100% 'parallel_hostscopy {}' ::: $userlist
	else
		ec red "Warning: Userlist variable not detected when creating test file!"
	fi

	#test urls
	: > /usr/local/apache/htdocs/migration_test_urls.html #blank original tests file
	if [ "$domainlist" ]; then
		ec yellow "Generating migration test urls..."
		for domain in $domainlist; do
			echo "http://$domain/HostsCheck.php" >> /usr/local/apache/htdocs/migration_test_urls.html
		done
		test_urls=$(cat /usr/local/apache/htdocs/migration_test_urls.html | haste)
		#save hastbin url in $dir
		echo $test_urls > $dir/test_urls
	else
		ec red "Warning: Could not genearte test urls, no domainlist."
	fi

	#upload hostsfile_alt to hastebin:
	hostsfile_url=$(cat $hostsfile_alt | haste)
	echo $hostsfile_url > $dir/hostsfile_url

	#generate reply
	ec yellow "Generating response to customer..."
	cp -a /root/includes.pullsync/text_files/pullsync_reply.txt $dir/pullsync_reply.txt

	#edit reply
	sed -i -e "s|http://\${ip}/hostsfile.txt|$hostsfile_url|" -e "s|http://\${ip}/migration_test_urls.html|$test_urls|" $dir/pullsync_reply.txt

	#remove final sync message
	if [ $remove_final_sync_message ]; then
		sed -i -e '/ONCE YOU FINISH TESTING/,$d' -e "s/Switching\ DNS\ prematurely\ may\ prevent\ a\ final\ migration\ from\ taking\ place\.//" $dir/pullsync_reply.txt
		cat >> $dir/pullsync_reply.txt <<EOF
  ONCE YOU FINISH TESTING:

Once testing is complete, DNS for the migrated domains can be updated to make the new server live at your convenience. This is done at the current nameservers for each domain; let us know if you need help determining where your nameservers are. If you are planning to change nameservers, please let us know, and we can provide additional details on switching to Liquid Web's nameservers, or setting up your own custom nameservers.

We will not automatically terminate the old hosting solution; you must request this separately if you no longer need the old server.

Please let us know if you have any questions.
EOF
	fi

	#add stanza if malware found
	if ([ -s /root/dirty_accounts.txt ] && grep -q -E -e "^$(echo $userlist | sed -e 's/\ /|/g')$" /root/dirty_accounts.txt); then
		cat >> $dir/pullsync_reply.txt <<EOF

  IMPORTANT:

To help ensure our network's security, during migrations, we perform basic malware scanning on migrated accounts as they arrive. One or more of the accounts for this migration contained one or more of these security variances:

$(grep -E -e "^$(echo $userlist | sed -e 's/\ /|/g')$" /root/dirty_accounts.txt)

If you have any questions about any of the above information, please let us know.

Thanks!
EOF
	fi


	#send to paste server
	reply_url=$(cat $dir/pullsync_reply.txt | haste)
	echo $reply_url > $dir/reply_url
	ec green "Reply generated at $reply_url"
}
