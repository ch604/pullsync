basic_optimize_keepalive(){ #enable keepalive by adjusting the cpanel apache settings. settings file is missing on modern cpanel.
	# ensure keepalive is on in apache settings and rebuild config
	if [ "$localea" = "EA4" ]; then
		sed -i.lwbak '/\"keepalive\"\ \:/ s/[oO]ff/On/' /etc/cpanel/ea4/ea4.conf
	else
		if [ -f /var/cpanel/conf/apache/local ]; then
			sed -i.lwbak '/\"keepalive\"\:/ s/[oO]ff/On/' /var/cpanel/conf/apache/local
		else
			echo '"keepalive": On' >> /var/cpanel/conf/apache/local
		fi
	fi
	/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
}
