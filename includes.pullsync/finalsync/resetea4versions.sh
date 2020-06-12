resetea4versions() { #run after final syncs in case .htaccess was overwritten from final
	for domain in $domainlist; do
		phpversion=$(grep ^$domain\:\  /etc/userdatadomains | awk -F"==" '{print $10}')
		/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -q ${phpversion} && /usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version=${phpversion:-inherit} vhost-0=$domain 2>&1 | stderrlogit 3
	done
}
