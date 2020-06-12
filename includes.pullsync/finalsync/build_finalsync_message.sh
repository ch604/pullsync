build_finalsync_message() { #create a ticket reply for post-finalsync based on server and nameserver information, including sync-specific information
	local cmd=(dialog --nocancel --colors --clear --backtitle "pullsync" --title "Build Final Sync Message" --radiolist "Select a nameserver hosting option for building the post-final message to the client.\n" 0 0 7)
	local options=( 1 "Internal to source (and customer will reuse same nameservers)" off
			2 "Customer will use brand new nameservers on new server" off
			3 "External to source (e.g. GoDaddy, Cloudflare, etc.)" off
			4 "Other (add your own information when copy/pasting)" off
			5 "IP swap, doesn't matter" off)

	ec yellow "Building finalsync reply..."
	sleep 1 #make it look like we are working
	echo -e "Hello,\n" > $dir/finalsyncreply.txt #blank the file

	#set up variables to add to the reply or guide suggestion
	local testuser=`echo $userlist | awk '{print $1}'`
	local testdomain=`grep ^DNS\= /var/cpanel/users/$testuser | cut -d\= -f2`
	local nameserver1=`cat /etc/wwwacct.conf | grep ^NS\  | awk '{print $2}'`
	local nameserver2=`cat /etc/wwwacct.conf | grep ^NS2\  | awk '{print $2}'`
	local snameserver1=`cat $dir/etc/wwwacct.conf | grep ^NS\  | awk '{print $2}'`
	local snameserver2=`cat $dir/etc/wwwacct.conf | grep ^NS2\  | awk '{print $2}'`
	[ -s /etc/ips ] && second_ip=`head -n1 /etc/ips | cut -d\: -f1` || second_ip=$cpanel_main_ip #second ip for second nameserver

	#use the nameserver registrar and contact information to guide suggestion
	local registrar=$(nameserver_registrar $nameserver1)
	[ "$registrar" = "" ] && unset registrar #bail if not detected
	if [ ! "$registrar" = "" ]; then
		cmd[9]=$(echo "${cmd[9]}\n${nameserver1}'s main domain seems to be registered at $registrar.\n")
	fi

	#create suggestion
	if [ "$ipswap" ]; then
		options[14]=on
		cmd[9]=$(echo "${cmd[9]}\nI recommend picking option 5, ipswap variable is set.")
	elif head -2 $dir/nameserver_summary.txt | grep -q $nameserver1 && head -2 $dir/nameserver_summary.txt | grep -q $nameserver2; then
		if [ ! "$copydns" ]; then
			options[8]=on
			cmd[9]=$(echo "${cmd[9]}\nI recommend picking option 3, top nameservers are those set on this machine, but you elected to not copy DNS.")
		else
			options[2]=on
			cmd[9]=$(echo "${cmd[9]}\nI recommend picking option 1, nameservers from /etc/wwwacct.conf match top two used nameservers.")
		fi
	elif ! head -2 $dir/nameserver_summary.txt | grep -q -e $nameserver1 -e $nameserver2 -e $snameserver1 -e $snameserver2; then
		options[8]=on
		cmd[9]=$(echo "${cmd[9]}\nI recommend picking option 3, top used nameservers are neither source or target's.")
	elif ! grep ^NS $dir/etc/wwwacct.conf | grep -q -e $nameserver1 -e $nameserver2; then
		options[5]=on
		cmd[9]=$(echo "${cmd[9]}\nI recommend picking option 2, nameservers do not match between source and target.")
	else
		options[11]=on
		cmd[9]=$(echo "${cmd[9]}\n\Z1I couldn't logic out what to pick... hope you know what to choose!\Zn")
	fi

	#print the menu
	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	clear
	echo $choices >> $log
	for choice in $choices; do print_next_element options $choice >> $log; done
	for choice in $choices; do
		case $choice in
			1) cat >> $dir/finalsyncreply.txt << EOF
The final sync is complete, and the DNS files for the domains have been synced back to the original server. This will make the sites live on the new server until you can update the nameserver IPs. You can see that the updates are public and propagated by using this tool:

https://www.whatsmydns.net/#A/$testdomain

DNS for any domains that do not depend on your internal nameservers should be updated at this time. Please also update the IPs for your nameservers (also known as the Glue) to the following:

${nameserver1:-ns1} - $cpanel_main_ip
${nameserver2:-ns2} - $second_ip

EOF
			if [ "$registrar" ]; then cat >> $dir/finalsyncreply.txt << EOF
This is done at the domain registrar for the main domain, which we found to be "$registrar". Let me know if you have any questions on this task. Once you update the nameserver IPs, the migration can be considered fully complete.

EOF
			else cat >> $dir/finalsyncreply.txt << EOF
This is done at the domain registrar for the main domain. Let me know if you have any questions on this task. Once you update the nameserver IPs, the migration can be considered fully complete.

EOF
			fi
			;;
			2) cat >> $dir/finalsyncreply.txt << EOF
The final sync is complete, and it is now time to update the DNS for your domains to the new nameservers, ${nameserver1} and ${nameserver2}. The nameservers for the domains are updated at their respective registrars. Please also ensure that the nameservers themselves are registered at their main domain's registrar. You can use the following IPs for each nameserver:

${nameserver1:-ns1} - $cpanel_main_ip
${nameserver2:-ns2} - $second_ip

EOF
			if [ "$registrar" ]; then cat >> $dir/finalsyncreply.txt << EOF
This is done at the domain registrar for the main domain, which we found to be "$registrar". Let me know if you have any questions on this task. Once you update the nameserver IPs and assign all domains to use them, the migration can be considered fully complete.

EOF
			else cat >> $dir/finalsyncreply.txt << EOF
This is done at the domain registrar for the main domain. Let me know if you have any questions on this task. Once you update the nameserver IPs and assign all domains to use them, the migration can be considered fully complete.

EOF
			fi
			;;
			3) cat >> $dir/finalsyncreply.txt << EOF
The final sync is complete. Now is the time to update DNS for your domains to the new IPs. This is done at the current nameservers for each migrated domain. Once you make these changes, you can check and see that the updates are public and propagated by using this tool:

https://www.whatsmydns.net/#A/$testdomain

Let us know if you have any questions on this task. Once you update the DNS, the migration can be considered fully complete.

EOF
			;;
			4) echo -e "[REPLACE ME WITH DNS DETAILS]\n[REPLACE ME WITH DNS DETAILS]\n[REPLACE ME WITH DNS DETAILS]\n" >> $dir/finalsyncreply.txt
			cue_tech_to_replace_dns_details=1
			;;
			5) cat >> $dir/finalsyncreply.txt << EOF
The final sync is finished, and the IP addresses for your server have been moved to the new machine and assigned to their respective original accounts. This has made the sites live on the new server, and the migration can now be considered fully complete.

EOF
			;;
			*) ec red "Invalid choice." ;;
		esac
	done

	#always print this part
	cat >> $dir/finalsyncreply.txt << EOF
If you made edits to your workstation's hosts file to test the sites during the course of the migration, these changes should be reverted at this time, so that your computer will start using public DNS records for your domains again. Leaving these hosts file records in place can cause issues with domain resolution in the future. If you need assistance editing your hosts file, please review the following link:

 https://www.howtogeek.com/howto/27350/beginner-geek-how-to-edit-your-hosts-file/

EOF

	# detect if cpanel backups are on
	if [ $(/usr/local/cpanel/bin/whmapi1 backup_config_get | grep backupenable: | awk '{print $2}') -eq 1 ]; then
		cat >> $dir/finalsyncreply.txt << EOF
Now is a good time to ensure that you have appropriate backups set up and enabled for your data. I show that cPanel backups are enabled on the new server, though you may wish to investigate the retention schedule. Server-side backups can be enabled and adjusted through WHM, and we also offer remote backup solutions for all server types. More details can be found at these links, and we are happy to go over the options available to you.

 https://www.liquidweb.com/kb/how-to-enable-server-backups-in-whmcpanel/

EOF
	else
		cat >> $dir/finalsyncreply.txt << EOF
Now is a good time to ensure that you have appropriate backups set up and enabled for your data, and I show that presently, cPanel backups are DISABLED on the target server. Server-side backups can be enabled through WHM, and we also offer remote backup solutions for all server types. More details can be found at these links, and we are happy to go over the options available to you.

 https://www.liquidweb.com/kb/how-to-enable-server-backups-in-whmcpanel/
EOF
	fi

	cat >> $dir/finalsyncreply.txt << EOF
Keep in mind that we will not automatically cancel the old hosting solution for you; this must be done with the old hosting company separately following the update of DNS.

As always, please let us know if you have any questions or encounter any issues with the new server.
EOF
}
