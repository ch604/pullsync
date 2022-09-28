detect_apps() { # look for common extra applications
	#first, look for installed things on source
	ec yellow "Checking for 3rd party apps..."
	psfile=$(mktemp) #avoid too many ssh sessions by storing output of ps early
	sssh "ps acx" > $psfile
	ffmpeg=`sssh "which ffmpeg 2> /dev/null"`
	imagick=`sssh "which convert 2> /dev/null"`
	memcache=`grep -e 'memcache' $psfile` #memcache is actually installed during optimizations() instad of installs() but thats ok
	redis=`sssh "which redis-server 2> /dev/null"`
	elasticsearch=`sssh "ps faux | grep -e 'elasticsearch' | grep -v grep"`
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
	apc=`grep -x -e apc -e apcu $dir/remote_php_details.txt`
	sodium=`grep -x -e sodium $dir/remote_php_details.txt`
	cpanelsolr=`sssh "service cpanel-dovecot-solr status 2> /dev/null"`
	# check for configserver WHM plugins
	[ -f $dir/var/cpanel/apps/cmc.conf ] && [ ! -f /var/cpanel/apps/cmc.conf ] && cmc=1
	[ -f $dir/var/cpanel/apps/cmm.conf ] && [ ! -f /var/cpanel/apps/cmm.conf ] && cmm=1
	[ -f $dir/var/cpanel/apps/cmq.conf ] && [ ! -f /var/cpanel/apps/cmq.conf ] && cmq=1
	[ -f $dir/var/cpanel/apps/cse.conf ] && [ ! -f /var/cpanel/apps/cse.conf ] && cse=1
	mailscanner=`[ ! -d /usr/mailscanner ] && sssh "[ -d /usr/mailscanner ] && echo 1"`
	[ $mailscanner ] && unset spamassassin
	nginxfound=`grep -e 'nginx' $psfile`

	#detect stuff we cant install
	xcachefound=`grep -e 'xcache' $psfile`
	varnishfound=`grep -e 'varnishd' $psfile`
	eaccelfound=`grep -e 'eaccelerator' $psfile`
	lswsfound=`grep -Ee '(litespeed|lsws|lshttpd)' $psfile`
	mongodfound=`grep -e 'mongod' $psfile`
	modcloudflarefound=`sssh "httpd -M 2> /dev/null | grep cloudflare"`
	[ -f $dir/var/cpanel/apps/cxs.conf ] && cxsfound=/var/cpanel/apps/cxs.conf
	[ -f $dir/var/cpanel/domainmap ] && domainmap=1
	[ -f $dir/usr/local/apache/conf/modsec2/00_asl_whitelist.conf -o -f $dir/etc/apache2/conf.d/modsec2/00_asl_whitelist.conf ] && turtlerules=1
	rvsbfound=`sssh "[ -d /var/cpanel/rvglobalsoft/rvsitebuilder/ ] && echo 1"`
	if [ "${xcachefound}${varnishfound}${eaccelfound}${lswsfound}${mongodfound}${cxsfound}${domainmap}${rvsbfound}" ]; then
		ec white "3rd party stuff found on the old server! (cat $dir/uninstallable.txt)" | errorlogit 4
		(
		[ "$xcachefound" ] && echo "Xcache: $xcachefound"
		[ "$varnishfound" ] && echo "Varnish: $varnishfound"
		[ "$eaccelfound" ] && echo "Eaccelerator: $eaccelfound"
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

	#next, remove items already installed and put them in a separate list
	ec yellow "Trimming already-installed programs..."
	psfile2=$(mktemp)
	ps acx > $psfile
	[ "$ffmpeg" ] && which ffmpeg &> /dev/null && unset ffmpeg && echo "ffmpeg" >> $dir/skippedinstall.txt
	[ "$imagick" ] && which convert &> /dev/null && unset imagick && echo "imagick" >> $dir/skippedinstall.txt
	[ "$memcache" ] && grep -q -e 'memcache' $psfile2 && unset memcache && echo "memcache" >> $dir/skippedinstall.txt
	[ "$redis" ] && which redis-server &> /dev/null && unset redis && echo "redis" >> $dir/skippedinstall.txt
	[ "$elasticsearch" ] && service elasticsearch status &> /dev/null && unset elasticsearch && echo "elasticsearch" >> $dir/skippedinstall.txt
	[ "$maldet" ] && which maldet &> /dev/null && unset maldet && echo "maldet" >> $dir/skippedinstall.txt
	[ "$java" ] && which java &> /dev/null && unset java javaver && echo "java" >> $dir/skippedinstall.txt
	[ "$solr" ] && /etc/init.d/solr status &> /dev/null && unset solr && echo "solr" >> $dir/skippedinstall.txt
	[ "$wkhtmltopdf" ] && which wkhtmltopdf &> /dev/null && unset wkhtmltopdf && echo "wkhtmltopdf" >> $dir/skippedinstall.txt
	[ "$pdftk" ] && which pdftk &> /dev/null && unset pdftk && echo "pdftk" >> $dir/skippedinstall.txt
	[ "$postgres" ] && pgrep postgres &> /dev/null && unset postgres && echo "postgres" >> $dir/skippedinstall.txt
	[ "$nodejs" ] && which node &> /dev/null && unset nodejs npm && echo "nodejs" >> $dir/skippedinstall.txt
	[ "$tomcat" ] && which tomcat &> /dev/null && unset tomcat && echo "tomcat" >> $dir/skippedinstall.txt
	[ "$cpanelsolr" ] && service cpanel-dovecot-solr status &> /dev/null && unset cpanelsolr && echo "cpanelsolr" >> $dir/skippedinstall.txt
	rm -f $psfile2

	#print out the programs we detected
	ec yellow "Program scan results:"
	for prog in $proglist; do
		ec $([ "${!prog}" ] && echo green || echo red) " $prog"
	done
	[ -s $dir/skippedinstall.txt ] && ec yellow "Some programs were already detected on target and will not be installed" && cat $dir/skippedinstall.txt
}
