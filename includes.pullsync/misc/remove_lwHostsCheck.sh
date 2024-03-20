remove_lwHostsCheck() { #delete files called lwHostsCheck.php from every docroot in the userlist
	if [ "$userlist" ]; then
		ec Yellow "Erasing lwHostsCheck.php files..."
		for user in $userlist; do
			local userhome_local=`eval echo ~${user}`
			docroot=`grep DocumentRoot /usr/local/apache/conf/httpd.conf |grep $userhome_local| awk '{print $2}'`
			[ -f "$docroot/lwHostsCheck.php" ] && rm $docroot/lwHostsCheck.php && echo "$docroot/lwHostsCheck.php" >> $dir/log/removed_lwHostsCheck_files.txt
		done
	else
		ec Yellow "No userlist variable, erasing lwHostsCheck.php from all docroots..."
		docroots=$(awk '/DocumentRoot/ {print $2}' /usr/local/apache/conf/httpd.conf | sort -u)
		for docroot in $docroots; do
			[ -f "$docroot/lwHostsCheck.php" ] && rm $docroot/lwHostsCheck.php && echo "$docroot/lwHostsCheck.php" >> $dir/log/removed_lwHostsCheck_files.txt
		done
	fi
}
