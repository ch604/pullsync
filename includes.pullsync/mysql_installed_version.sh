mysql_installed_version() { #legacy fix for mismatch between installed mysql and what cpanel thinks is installed
	# skip this check if using remote mysql
	[ "$targetremotemysql" ] && return
	# if running mysql doesnt match cpanel.config, fix it
	if [ "$(awk -F= '/^mysql-version=/ {print $2}' /var/cpanel/cpanel.config)" != "$localmysql" ]; then
		ec red "Local mysql version does not match what is stored in cpanel.config:"
		grep ^mysql-version= /var/cpanel/cpanel.config | logit
		if yesNo "Fix this now to read 'mysql-version=$localmysql'?"; then
			ec green "Say no more fam. Backup at /var/cpanel/cpanel.config.mysqlverbak."
			sed -i.mysqlverbak 's/\(^mysql-version=\).*/\1'"$localmysql"'/' /var/cpanel/cpanel.config
		fi
	fi
}
