remove_HostsCheck() { #delete files called HostsCheck.php from every docroot in the userlist
	if [ "$userlist" ]; then
		local userhome_local
		for user in $userlist; do
			userhome_local=$(eval echo ~${user})
			docroots=$(awk '/DocumentRoot/ {print $2}' /usr/local/apache/conf/httpd.conf | grep "^$userhome_local" | sort -u)
			for docroot in $docroots; do
				if [ -f "$docroot/HostsCheck.php" ]; then
					rm -f "$docroot/HostsCheck.php"
					echo "$docroot/HostsCheck.php" >> $dir/log/removed_HostsCheck_files.txt
				fi
			done
		done
	else
		docroots=$(awk '/DocumentRoot/ {print $2}' /usr/local/apache/conf/httpd.conf | sort -u)
		for docroot in $docroots; do
			if [ -f "$docroot/HostsCheck.php" ]; then
				rm -f "$docroot/HostsCheck.php"
				echo "$docroot/HostsCheck.php" >> $dir/log/removed_HostsCheck_files.txt
			fi
		done
	fi
}
