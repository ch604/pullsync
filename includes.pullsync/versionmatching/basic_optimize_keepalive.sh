basic_optimize_keepalive(){ #enable keepalive by adjusting the cpanel apache settings
	# ensure keepalive is on in apache settings and rebuild config
	sed -i.pullsyncbak '/\"keepalive\"\:/ s/[oO]ff/On/' /var/cpanel/conf/apache/local
	/scripts/rebuildhttpdconf
}
