fpmconvert () { #imports the phpfpm settings of the user from the source machine. if force is 1, converts all domains to fpm regardless of source handle
	local user=$1
	local force=$2
	for dom in `cat /etc/userdomains | grep \ ${user}$ | awk -F: '{print $1}'`; do #run twice, to set non-inherit version and then turn on fpm
		if [ $force -eq 1 ] || [ -f $dir/var/cpanel/userdata/$user/$dom.php-fpm.yaml ]; then
			parentdom=$(grep -l $dom $dir/var/cpanel/userdata/$user/* | egrep -v -e '(cache|main|json|_SSL|yaml)$' | head -n1 | awk -F\/ '{print $NF}')
			newphpver=$(grep ^phpversion: $dir/var/cpanel/userdata/$user/$parentdom | awk '{print $2}')
			! /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q $newphpver && newphpver=$defaultea4profile
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$newphpver php_fpm=1 vhost-0=$dom 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$newphpver php_fpm=1 vhost-0=$dom 2>&1 | stderrlogit 3
			if [ -f $dir/var/cpanel/userdata/$user/$dom.php-fpm.yaml ]; then
				\cp -af $dir/var/cpanel/userdata/$user/$dom.php-fpm.yaml /var/cpanel/userdata/$user/
				\rm -f /var/cpanel/userdata/$user/$dom.php-fpm.cache
				/scripts/php_fpm_config --rebuild --domain=$dom &> /dev/null
			fi
		fi
	done
}
