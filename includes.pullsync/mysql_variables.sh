mysql_variables() {
	if [ ! "$synctype" = "single" ]; then
		# on non-single (non shared) migrations, ensure open_files_limit and skip_name_resolve variables
		if ! grep -q ^open_files_limit /etc/my.cnf ;then
			ec yellow "Adding open_files_limit = 50000 to my.cnf, restarting mysql..."
			sed -i 's/\(\[mysqld\]\)/\1\nopen_files_limit = 50000/' /etc/my.cnf
			/scripts/restartsrv_mysql 2>&1 >/dev/null
			if [ ! "$(mysqladmin status 2> /dev/null)" ]; then
				ec red "Setting open_files_limit caused mysql to fail! Reverting!" | errorlogit 3
				sed -i '/^open_files_limit\ /d' /etc/my.cnf
				/scripts/restartsrv_mysql 2>&1 >/dev/null
			fi
		fi
		if grep -q -x skip_name_resolve /etc/my.cnf ; then
			ec yellow "Commenting out skip_name_resolve from my.cnf, restarting mysql and cpanel..."
			sed -i '/^skip_name_resolve$/s/^/#/' /etc/my.cnf
			/scripts/restartsrv_mysql 2>&1 >/dev/null
			/scripts/restartsrv_cpsrvd 2>&1 >/dev/null
		fi
	fi
}
