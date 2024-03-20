fpmconvert () { #imports the phpfpm settings and php version of the given user's domains from the source machine. if force is 1, converts all domains to fpm regardless of source handler
	local user=$1
	local force=$2
	for dom in $(awk -F: '/ '${user}'$/ {print $1}' /etc/userdomains); do
		if [ -f $dir/var/cpanel/userdata/$user/$dom ]; then
			parentdom=$dom
		else
			parentdom=$(grep -l \ $dom $dir/var/cpanel/userdata/$user/* | egrep -v -e '(cache|main|json|_SSL|yaml)$' | head -n1 | awk -F\/ '{print $NF}')
		fi
		newphpver=$(awk '/^phpversion:/ {print $2}' $dir/var/cpanel/userdata/$user/$parentdom)
		! /usr/local/cpanel/bin/rebuild_phpconf --available | grep -q $newphpver && newphpver=$defaultea4profile
		if [ $force -eq 1 ] || [ -f $dir/var/cpanel/userdata/$user/$dom.php-fpm.yaml ]; then
			#run twice, to set non-inherit version and then turn on fpm
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$newphpver php_fpm=1 vhost-0=$dom 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$newphpver php_fpm=1 vhost-0=$dom 2>&1 | stderrlogit 3
		else
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$newphpver php_fpm=0 vhost-0=$dom 2>&1 | stderrlogit 3
			/usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=$newphpver php_fpm=0 vhost-0=$dom 2>&1 | stderrlogit 3
		fi
		if [ -f $dir/var/cpanel/userdata/$user/$dom.php-fpm.yaml ]; then
			\cp -af $dir/var/cpanel/userdata/$user/$dom.php-fpm.yaml /var/cpanel/userdata/$user/
			\rm -f /var/cpanel/userdata/$user/$dom.php-fpm.cache
			/scripts/php_fpm_config --rebuild --domain=$dom &> /dev/null
		fi
	done
}
