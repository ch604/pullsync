resetea4versions() { #run after final syncs in case .htaccess was overwritten from final
	for domain in $domainlist; do
		phpversion=$(awk -F"==" '/^'$domain': / {print $10}' /etc/userdatadomains)
		/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1 | grep -q ${phpversion} && whmapi1 php_set_vhost_versions version=${phpversion:-inherit} vhost-0=$domain 2>&1 | stderrlogit 3
	done
}
