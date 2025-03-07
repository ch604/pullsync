install_security() { #install optional security settings
	if [ $enable_modsec ]; then
		ec yellow "$hg Enabling OWASP ModSec ruleset"
		yum -yq --skip-broken install ea-modsec-sdbm-util ea-modsec2-rules-owasp-crs 2>&1 | stderrlogit 3
		/scripts/modsec_vendor enable OWASP3 2>&1 | stderrlogit 3
		writecm
	fi

	if [ $enable_modevasive ]; then
		ec yellow "$hg Installing mod_evasive with default options"
		yum -yq install ea-apache24-mod_evasive 2>&1 | stderrlogit 3
		writecm
	fi

	if [ $enable_modreqtimeout ]; then
		ec yellow "$hg Installing mod_reqtimeout with default options"
		yum -yq install ea-apache24-mod_reqtimeout 2>&1 | stderrlogit 3
		! grep -q RequestReadTimeout /etc/apache2/conf.d/includes/*.conf && echo "
<IfModule mod_reqtimeout.c>
  RequestReadTimeout header=20-40,MinRate=500 body=20-40,MinRate=500
</IfModule>" >> /etc/apache2/conf.d/includes/pre_main_global.conf
		writecm
	fi

	if [ $disable_moduserdir ]; then
		ec yellow "$hg Disabling mod_userdir globally"
		! grep -q UserDir\ disabled /etc/apache2/conf.d/includes/*.conf && echo "
<IfModule userdir_module>
  UserDir disabled
</IfModule>" >> /etc/apache2/conf.d/includes/post_virtualhost_global.conf
		writecm
	fi
	
	/scripts/restartsrv_apache 2>&1 | stderrlogit 3
}
