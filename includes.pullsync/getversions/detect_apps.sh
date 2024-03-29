detect_apps() { # look for common extra applications
	#first, look for installed things on source
	ec yellow "Checking for 3rd party apps..."
	psfile=$(mktemp) #avoid too many ssh sessions by storing output of ps early
	sssh "ps ax" > $psfile
	ffmpeg=$(sssh "which ffmpeg 2> /dev/null")
	imagick=$(sssh "which convert 2> /dev/null")
	memcache=$(grep -e 'memcache' $psfile)
	redis=$(grep -e 'redis-server' $psfile)
	elasticsearch=$(grep -e 'elasticsearch' $psfile)
	maldet=$(sssh "which maldet 2> /dev/null")
	[ $(awk -F= '/^skipspamassassin=/ {print $2}' $dir/var/cpanel/cpanel.config) = 0 ] && [ $(awk -F= '/^skipspamassassin=/ {print $2}' /var/cpanel/cpanel.config) = 1 ] && spamassassin=1
	java=$(sssh "which java 2> /dev/null")
	if [ "$java" ]; then
		local javafullver=$(sssh "java -version 2>&1" | head -n1 | cut -d\" -f2)
		if [ $(echo $javafullver | cut -d. -f1) -eq 1 ]; then #1.6 through 1.8
			javaver=$(echo $javafullver | cut -d. -f2)
		else #higher versions
			javaver=$(echo $javafullver | cut -d. -f1)
		fi
		#trim java versions by os ver
		if [ "$(rpm --eval %rhel)" -ge 9 ]; then
			case $javaver in
				17|21|22) :;;
				*) javaver=17;;
			esac
		elif [ "$(rpm --eval %rhel)" -eq 8 ]; then
			case $javaver in
				8|11|17|21|22) :;;
				*) javaver=11;;
			esac
		else #el7 or lower
			case $javaver in
				8|11) :;;
				*) javaver=8;;
			esac
		fi
	fi
	[ "$java" ] && solr=$(sssh "/etc/init.d/solr status 2> /dev/null") #TODO might be a more universal check method
	if [ "$solr" ] && [ "$javaver" -le 8 ]; then
		#latest solr install requires java 11+
		javaver=11
	fi
	wkhtmltopdf=$(sssh "which wkhtmltopdf 2> /dev/null")
	pdftk=$(sssh "which pdftk 2> /dev/null")
	[ "$pdftk" ] && [ ! "$java" ] && java=1 && javaver=11
	sssh "pgrep postgres &> /dev/null" || sssh "pgrep postmaster &> /dev/null" && postgres="found"
	nodejs=$(sssh "which node 2> /dev/null")
	npm=$(sssh "which npm 2> /dev/null")
	[ "$nodejs" ] && [ "$npm" ] && npmlist=$(sssh "npm ls -g --depth=0" | tail -n+2 | awk '{print $2}' | cut -d@ -f1 | grep -v npm | grep [a-zA-Z])
	tomcat=$(sssh "which tomcat 2> /dev/null; \ls /usr/local/cpanel/scripts/ea-tomcat85 2> /dev/null")
	apc=$(grep -x -e apc -e apcu $dir/remote_php_details.txt)
	sodium=$(grep -x -e sodium $dir/remote_php_details.txt)
	cpanelsolr=$(grep -e 'cpanelsolr' $psfile)
	# check for configserver WHM plugins
	[ -f $dir/var/cpanel/apps/cmc.conf ] && [ ! -f /var/cpanel/apps/cmc.conf ] && cmc=1
	[ -f $dir/var/cpanel/apps/cmm.conf ] && [ ! -f /var/cpanel/apps/cmm.conf ] && cmm=1
	[ -f $dir/var/cpanel/apps/cmq.conf ] && [ ! -f /var/cpanel/apps/cmq.conf ] && cmq=1
	[ -f $dir/var/cpanel/apps/cse.conf ] && [ ! -f /var/cpanel/apps/cse.conf ] && cse=1
	mailscanner=$([ ! -d /usr/mailscanner ] && sssh "[ -d /usr/mailscanner ] && echo 1")
	[ $mailscanner ] && unset spamassassin
	modremoteip=$(sssh "httpd -M 2> /dev/null" | grep -E '(cloudflare|remoteip|rpaf)'_module)
	nginxfound=$(grep -e 'nginx' $psfile)

	#detect stuff we cant install
	xcachefound=$(grep -e 'xcache' $psfile)
	varnishfound=$(grep -e 'varnishd' $psfile)
	eaccelfound=$(grep -e 'eaccelerator' $psfile)
	lswsfound=$(grep -Ee '(litespeed|lsws|lshttpd)' $psfile)
	mongodfound=$(grep -e 'mongod' $psfile)
	mssqlfound=$(grep -e 'sqlservr' $psfile)
	[ -f $dir/var/cpanel/apps/cxs.conf ] && cxsfound=/var/cpanel/apps/cxs.conf
	rvsbfound=$(sssh "[ -d /var/cpanel/rvglobalsoft/rvsitebuilder/ ] && echo 1")
	[ -f $dir/var/cpanel/domainmap ] && domainmap=1
	[ -f $dir/usr/local/apache/conf/modsec2/00_asl_whitelist.conf -o -f $dir/etc/apache2/conf.d/modsec2/00_asl_whitelist.conf ] && turtlerules=1
	ffmpegphp=$(grep -x -e ffmpeg $dir/remote_php_details.txt)
	eapodman=$(sssh "[ -f /usr/local/cpanel/scripts/ea-podman ] && echo 1")
	if [ "${xcachefound}${varnishfound}${eaccelfound}${lswsfound}${mongodfound}${mssqlfound}${cxsfound}${rvsbfound}${domainmap}${turtlerules}${ffmpegphp}${eapodman}" ]; then
		ec white "3rd party stuff found on the old server! (cat $dir/uninstallable.txt)" | errorlogit 4
		(
		[ "$xcachefound" ] && echo "Xcache: $xcachefound"
		[ "$varnishfound" ] && echo "Varnish: $varnishfound"
		[ "$eaccelfound" ] && echo "Eaccelerator: $eaccelfound"
		[ "$lswsfound" ] && echo "Litespeed: $lswsfound"
		[ "$mongodfound" ] && echo "Mongod: $mongodfound"
		[ "$mssqlfound" ] && echo "MSSQL: $mssqlfound"
		[ "$cxsfound" ] && echo "Configserver eXploit Scanner: $cxsfound"
		[ "$rvsbfound" ] && echo "RVSiteBuilder: /var/cpanel/rvglobalsoft/rvsitebuilder/"
		[ "$domainmap" ] && echo "WHM Domain Forwarding: /var/cpanel/domainmap"
		[ "$turtlerules" ] && echo "ModSec Turtle Rules: /usr/local/apache/conf/modsec2 or /etc/apache2/conf.d/modsec2"
		[ "$ffmpegphp" ] && echo "FFMPEG-PHP (not available on php7+): $ffmpegphp"
		[ "$eapodman" ] && echo "ea-podman: /usr/local/cpanel/scripts/ea-podman"
		) | tee -a $dir/uninstallable.txt | logit
		ec lightRed "It is up to you to license/install these and migrate as needed. Good luck t'ye."
		say_ok
	fi
	\rm -f $psfile

	#next, remove items already installed and put them in a separate list
	ec yellow "Trimming already-installed programs..."
	psfile2=$(mktemp)
	ps acx > $psfile2
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
	[ "$tomcat" ] && \ls /usr/local/cpanel/scripts/ea-tomcat85 &> /dev/null && unset tomcat && echo "tomcat" >> $dir/skippedinstall.txt
	[ "$cpanelsolr" ] && service cpanel-dovecot-solr status &> /dev/null && unset cpanelsolr && echo "cpanelsolr" >> $dir/skippedinstall.txt
	[ "$modremoteip" ] && rpm -q --quiet ea-apache24-mod_remoteip && unset modremoteip && echo "modremoteip" >> $dir/skippedinstall.txt
	\rm -f $psfile2

	#print out the programs we detected
	ec yellow "Program scan results:"
	for prog in $proglist; do
		ec $([ "${!prog}" ] && echo green || echo red) " $prog"
	done
	[ -s $dir/skippedinstall.txt ] && ec lightRed "Some programs will not be installed due to target configuration (cat $dir/skippedinstall.txt):" && cat $dir/skippedinstall.txt | logit
}
