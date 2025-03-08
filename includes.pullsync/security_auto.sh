security_auto() { #run outside of matching_menu() in case version matching is not needed, but security options are wanted
	#modsec
	if [ "$(whmapi1 modsec_is_installed | awk '/installed: / {print $2}')" -eq 1 ]; then
		if ! whmapi1 modsec_get_vendors | awk '/enabled: / {print $2}' | grep -q 1; then
			enable_modsec=1
		fi
	else
		enable_modsec=1
	fi

	#mod_userdir
	if ! rpm --quiet -q ea-apache24-mod_mpm_itk && ! rpm --quiet -q ea-apache24-mod_ruid2 && ! rpm --quiet -q ea-ruby24-mod_passenger && ! rpm --quiet -q ea-apache24-mod-passenger; then
		disable_moduserdir=1
	fi

	#mod_reqtimeout
	if ! rpm --quiet -q ea-apache24-mod_reqtimeout; then
		enable_modreqtimeout=1
	fi

	#mod_evasive
#	if ! rpm --quiet -q ea-apache24-mod_evasive; then
#		enable_modevasive=1
#	fi
}
