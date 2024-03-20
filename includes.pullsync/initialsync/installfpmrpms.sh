installfpmrpms() { #installs fpm for all installed php versions
	ec yellow "Installing supporting RPMs for PHP-FPM..."
	yum -y -q install ea-apache24-mod_proxy_fcgi $(for each in $(/usr/local/cpanel/bin/rebuild_phpconf --available | cut -d: -f1); do echo -n "$each-php-fpm "; done) 2>&1 | stderrlogit 3
}
