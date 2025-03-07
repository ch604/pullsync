remove_HostsCheck() { #delete files called HostsCheck.php from every docroot in the userlist
	if [ "$userlist" ]; then
		ec Yellow "Erasing HostsCheck.php files..."
		for user in $userlist; do
			local userhome_local=$(eval echo ~${user})
			docroot=$(grep DocumentRoot /usr/local/apache/conf/httpd.conf | grep $userhome_local | awk '{print $2}')
			[ -f "$docroot/HostsCheck.php" ] && rm $docroot/HostsCheck.php && echo "$docroot/HostsCheck.php" >> $dir/log/removed_HostsCheck_files.txt
		done
	else
		ec Yellow "No userlist variable, erasing HostsCheck.php from all docroots..."
		docroots=$(awk '/DocumentRoot/ {print $2}' /usr/local/apache/conf/httpd.conf | sort -u)
		for docroot in $docroots; do
			[ -f "$docroot/HostsCheck.php" ] && rm $docroot/HostsCheck.php && echo "$docroot/HostsCheck.php" >> $dir/log/removed_HostsCheck_files.txt
		done
	fi
}
