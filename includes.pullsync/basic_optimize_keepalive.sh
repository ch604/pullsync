basic_optimize_keepalive(){ #enable keepalive by adjusting the cpanel apache settings.
	# ensure keepalive is on in apache settings and rebuild config
	sed -i.pullsyncbak '/\"keepalive\"\ \:/ s/[oO]ff/On/' /etc/cpanel/ea4/ea4.conf
	/scripts/rebuildhttpdconf 2>&1 | stderrlogit 3
}
