detect_apps() { # look for common extra applications
	ec yellow "Checking for 3rd party apps..."
	psfile=$(mktemp) #avoid too many ssh sessions by storing output of ps early
	sssh "ps acx" > $psfile
	ffmpeg=`sssh "which ffmpeg 2> /dev/null"`
	imagick=`sssh "which convert 2> /dev/null"`
	memcache=`grep -e 'memcache' $psfile` #memcache is actually installed during optimizations() instad of installs() but thats ok
	redis=`sssh "which redis-server 2> /dev/null"`
	maldet=`sssh "which maldet 2> /dev/null"`
	[ $(grep ^skipspamassassin\= $dir/var/cpanel/cpanel.config | cut -d= -f2) = 0 ] && [ $(grep ^skipspamassassin\= /var/cpanel/cpanel.config | cut -d= -f2) = 1 ] && spamassassin=1
	java=`sssh "which java 2> /dev/null"`
	[ "$java" ] && solr=`sssh "/etc/init.d/solr status 2> /dev/null"` #might be a more universal check method
	wkhtmltopdf=`sssh "which wkhtmltopdf 2> /dev/null"`
	pdftk=`sssh "which pdftk 2> /dev/null"`
	sssh "pgrep postgres &> /dev/null" || sssh "pgrep postmaster &> /dev/null" && postgres="found"
	nodejs=`sssh "which node 2> /dev/null"`
	npm=`sssh "which npm 2> /dev/null"`
	[ "$nodejs" ] && [ "$npm" ] && npmlist=`sssh "npm ls -g --depth=0" | tail -n+2 | awk '{print $2}' | cut -d@ -f1 | grep -v npm | grep [a-zA-Z]`
	tomcat=`sssh "which tomcat 2> /dev/null"`
	[ "$(echo $local_os | grep -o '[0-9]\+' | head -n1)" -ne 7 ] && unset tomcat #install only works on cent7
	[ "$tomcat" ] && java=1 #java must be installed for tomcat
	apc=`grep -x apc $dir/remote_php_details.txt`
	cpanelsolr=`sssh "service cpanel-dovecot-solr status 2> /dev/null"`
	# check for configserver WHM plugins
	[ -f $dir/var/cpanel/apps/cmc.conf ] && [ ! -f /var/cpanel/apps/cmc.conf ] && cmc=1
	[ -f $dir/var/cpanel/apps/cmm.conf ] && [ ! -f /var/cpanel/apps/cmm.conf ] && cmm=1
	[ -f $dir/var/cpanel/apps/cmq.conf ] && [ ! -f /var/cpanel/apps/cmq.conf ] && cmq=1
	[ -f $dir/var/cpanel/apps/cse.conf ] && [ ! -f /var/cpanel/apps/cse.conf ] && cse=1
	mailscanner=`[ ! -d /usr/mailscanner ] && sssh "[ -d /usr/mailscanner ] && echo 1"`
	[ $mailscanner ] && unset spamassassin

	#detect stuff we cant install with pullsync
	xcachefound=`grep -e 'xcache' $psfile`
	varnishfound=`grep -e 'varnishd' $psfile`
	eaccelfound=`grep -e 'eaccelerator' $psfile`
	nginxfound=`grep -e 'nginx' $psfile`
	lswsfound=`grep -Ee '(litespeed|lsws|lshttpd)' $psfile`
	mongodfound=`grep -e 'mongod' $psfile`
	modcloudflarefound=`sssh "httpd -M 2> /dev/null | grep cloudflare"`
	[ -f $dir/var/cpanel/apps/cxs.conf ] && cxsfound=/var/cpanel/apps/cxs.conf
	[ -f $dir/var/cpanel/domainmap ] && domainmap=1
	[ -f $dir/usr/local/apache/conf/modsec2/00_asl_whitelist.conf -o -f $dir/etc/apache2/conf.d/modsec2/00_asl_whitelist.conf ] && turtlerules=1
	rvsbfound=`sssh "[ -d /var/cpanel/rvglobalsoft/rvsitebuilder/ ] && echo 1"`
	if [ "${xcachefound}${varnishfound}${eaccelfound}${nginxfound}${lswsfound}${mongodfound}${cxsfound}${domainmap}${rvsbfound}" ]; then
		ec white "3rd party stuff found on the old server! (cat $dir/uninstallable.txt)" | errorlogit 4
		(
		[ "$xcachefound" ] && echo "Xcache: $xcachefound"
		[ "$varnishfound" ] && echo "Varnish: $varnishfound"
		[ "$eaccelfound" ] && echo "Eaccelerator: $eaccelfound"
		[ "$nginxfound" ] && echo "Nginx: $nginxfound"
		[ "$lswsfound" ] && echo "Litespeed: $lswsfound"
		[ "$mongodfound" ] && echo "Mongod: $mongodfound"
		[ "$cxsfound" ] && echo "Configserver eXploit Scanner: $cxsfound"
		[ "$rvsbfound" ] && echo "RVSiteBuilder: /var/cpanel/rvglobalsoft/rvsitebuilder/"
		[ "$domainmap" ] && echo "WHM Domain Forwarding: /var/cpanel/domainmap"
		[ "$turtlerules" ] && echo "ModSec Turtle Rules: /usr/local/apache/conf/modsec2 or /etc/apache2/conf.d/modsec2"
		) | tee -a $dir/uninstallable.txt | logit
		ec lightRed "It is up to you to license/install these. Good luck t'ye."
		say_ok
	fi
	rm -f $psfile

	#print out the programs we detected
	ec yellow "Program scan results:"
	for prog in $proglist; do
		ec $([ "${!prog}" ] && echo green || echo red) " $prog"
	done
}
