cpconfbackup() {
	ec yellow "Backing up cPanel tweak settings..."
	if [ $(cut -d. -f2 /usr/local/cpanel/version) -ge 56 ]; then
		/usr/local/cpanel/bin/cpconftool --backup --modules=cpanel::smtp::exim,cpanel::system::whmconf 2>&1 | stderrlogit 4
		local backupexitcode=${PIPESTATUS[0]}
	else
		/usr/local/cpanel/bin/cpconftool --backup 2>&1 | stderrlogit 4
		local backupexitcode=${PIPESTATUS[0]}
	fi
	if [ "$backupexitcode" = "0" ]; then
		mv $(\ls -t /home*/whm-config-backup*.tar.gz | head -n1) $dir/whm-config-backup-all-original.tar.gz
		ec green "Success!"
	else
		cp -a /var/cpanel/cpanel.config $dir/cpanel.config.original
		ec red "Failed to run cpconftool; made a backup of cpanel.config at $dir/cpanel.config.original instead." | errorlogit 3
	fi

}
