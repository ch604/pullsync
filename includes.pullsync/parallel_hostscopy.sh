parallel_hostscopy() { #quoting the awk was too hard, made a sub function instead
	user=$1
	userhome_local=$(grep "^$user:" /etc/passwd | cut -d: -f6)
	docroots=$(awk '/DocumentRoot/ {print $2}' /usr/local/apache/conf/httpd.conf | grep "^$userhome_local" | sort -u)
	for docroot in $docroots; do
		cp -a "$dir/HostsCheck.php" "$docroot/"
		chown "$user":"$user" "$docroot/HostsCheck.php"
		chmod 644 "$docroot/HostsCheck.php"
	done
}